export solve_model!, solve_model

"""
    solution = solve_model!(energy_problem[, optimizer; parameters])

Solve the internal model of an `energy_problem`. The solution obtained by calling
[`solve_model`](@ref) is returned.
"""
function solve_model!(
    energy_problem::EnergyProblem,
    optimizer = HiGHS.Optimizer;
    parameters = default_parameters(optimizer),
)
    model = energy_problem.model
    if model === nothing
        error("Model is not created, run create_model(energy_problem) first.")
    end

    energy_problem.solution =
        solve_model!(model, energy_problem.variables, optimizer; parameters = parameters)
    energy_problem.termination_status = JuMP.termination_status(model)
    if energy_problem.solution === nothing
        # Warning has been given at internal function
        return
    end
    energy_problem.solved = true
    energy_problem.objective_value = JuMP.objective_value(model)

    graph = energy_problem.graph
    for ((y, a), value) in energy_problem.solution.assets_investment
        graph[a].investment[y] = graph[a].investment_integer ? round(Int, value) : value
    end

    for ((y, a), value) in energy_problem.solution.assets_investment_energy
        graph[a].investment_energy[y] =
            graph[a].investment_integer_storage_energy ? round(Int, value) : value
    end

    # TODO: fix this
    # for row in eachrow(energy_problem.dataframes[:storage_level_rep_period])
    #     a, rp, timesteps_block, value =
    #         row.asset, row.rep_period, row.timesteps_block, row.solution
    #     graph[a].storage_level_rep_period[(rp, timesteps_block)] = value
    # end
    #
    # for row in eachrow(energy_problem.dataframes[:storage_level_over_clustered_year])
    #     a, pb, value = row.asset, row.periods_block, row.solution
    #     graph[a].storage_level_over_clustered_year[pb] = value
    # end
    #
    # for row in eachrow(energy_problem.dataframes[:max_energy_over_clustered_year])
    #     a, pb, value = row.asset, row.periods_block, row.solution
    #     graph[a].max_energy_over_clustered_year[pb] = value
    # end
    #
    # for row in eachrow(energy_problem.dataframes[:max_energy_over_clustered_year])
    #     a, pb, value = row.asset, row.periods_block, row.solution
    #     graph[a].max_energy_over_clustered_year[pb] = value
    # end

    for ((y, (u, v)), value) in energy_problem.solution.flows_investment
        graph[u, v].investment[y] = graph[u, v].investment_integer ? round(Int, value) : value
    end

    # TODO: Fix this
    # for row in eachrow(energy_problem.variables[:flow].indices)
    #     u, v, rp, timesteps_block, value = row.from,
    #     row.to,
    #     row.rep_period,
    #     row.time_block_start:row.time_block_end,
    #     row.solution
    #     graph[u, v].flow[(rp, timesteps_block)] = value
    # end

    return energy_problem.solution
end

"""
    solution = solve_model!(dataframes, model, ...)

Solves the JuMP `model`, returns the solution, and modifies `dataframes` to include the solution.
The modifications made to `dataframes` are:

- `df_flows.solution = solution.flow`
- `df_storage_level_rep_period.solution = solution.storage_level_rep_period`
- `df_storage_level_over_clustered_year.solution = solution.storage_level_over_clustered_year`
"""
function solve_model!(model, args...; kwargs...)
    solution = solve_model(model, args...; kwargs...)
    if isnothing(solution)
        return nothing
    end

    # TODO: fix this later
    # dataframes[:flow].solution = solution.flow
    # dataframes[:storage_level_rep_period].solution = solution.storage_level_rep_period
    # dataframes[:storage_level_over_clustered_year].solution = solution.storage_level_over_clustered_year
    # dataframes[:max_energy_over_clustered_year].solution = solution.max_energy_over_clustered_year
    # dataframes[:min_energy_over_clustered_year].solution = solution.min_energy_over_clustered_year

    return solution
end

"""
    solution = solve_model(model[, optimizer; parameters])

Solve the JuMP model and return the solution. The `optimizer` argument should be an MILP solver from the JuMP
list of [supported solvers](https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers).
By default we use HiGHS.

The keyword argument `parameters` should be passed as a list of `key => value` pairs.
These can be created manually, obtained using [`default_parameters`](@ref), or read from a file
using [`read_parameters_from_file`](@ref).

The `solution` object is a mutable struct with the following fields:

  - `assets_investment[a]`: The investment for each asset, indexed on the investable asset `a`.
    To create a traditional array in the order given by the investable assets, one can run

    ```
    [solution.assets_investment[a] for a in labels(graph) if graph[a].investable]
    ```
    - `assets_investment_energy[a]`: The investment on energy component for each asset, indexed on the investable asset `a` with a `storage_method_energy` set to `true`.
    To create a traditional array in the order given by the investable assets, one can run

    ```
    [solution.assets_investment_energy[a] for a in labels(graph) if graph[a].investable && graph[a].storage_method_energy
    ```
  - `flows_investment[u, v]`: The investment for each flow, indexed on the investable flow `(u, v)`.
    To create a traditional array in the order given by the investable flows, one can run

    ```
    [solution.flows_investment[(u, v)] for (u, v) in edge_labels(graph) if graph[u, v].investable]
    ```
  - `storage_level_rep_period[a, rp, timesteps_block]`: The storage level for the storage asset `a` for a representative period `rp`
    and a time block `timesteps_block`. The list of time blocks is defined by `constraints_partitions`, which was used
    to create the model.
    To create a vector with all values of `storage_level_rep_period` for a given `a` and `rp`, one can run

    ```
    [solution.storage_level_rep_period[a, rp, timesteps_block] for timesteps_block in constraints_partitions[:lowest_resolution][(a, rp)]]
    ```
- `storage_level_over_clustered_year[a, pb]`: The storage level for the storage asset `a` for a periods block `pb`.
    To create a vector with all values of `storage_level_over_clustered_year` for a given `a`, one can run

    ```
    [solution.storage_level_over_clustered_year[a, bp] for bp in graph[a].timeframe_partitions[a]]
    ```
- `flow[(u, v), rp, timesteps_block]`: The flow value for a given flow `(u, v)` at a given representative period
    `rp`, and time block `timesteps_block`. The list of time blocks is defined by `graph[(u, v)].partitions[rp]`.
    To create a vector with all values of `flow` for a given `(u, v)` and `rp`, one can run

    ```
    [solution.flow[(u, v), rp, timesteps_block] for timesteps_block in graph[u, v].partitions[rp]]
    ```
- `objective_value`: A Float64 with the objective value at the solution.
- `duals`: A NamedTuple containing the dual variables of selected constraints.

## Examples

```julia
parameters = Dict{String,Any}("presolve" => "on", "time_limit" => 60.0, "output_flag" => true)
solution = solve_model(model, variables, HiGHS.Optimizer; parameters = parameters)
```
"""
function solve_model(
    model::JuMP.Model,
    variables,
    optimizer = HiGHS.Optimizer;
    parameters = default_parameters(optimizer),
)
    # Set optimizer and its parameters
    JuMP.set_optimizer(model, optimizer)
    for (k, v) in parameters
        JuMP.set_attribute(model, k, v)
    end
    # Solve model
    @timeit to "total solver time" JuMP.optimize!(model)

    # Check solution status
    if JuMP.termination_status(model) != JuMP.OPTIMAL
        @warn("Model status different from optimal")
        return nothing
    end

    dual_variables = @timeit to "compute_dual_variables" compute_dual_variables(model)

    return Solution(
        Dict(k => JuMP.value(v) for (k, v) in variables[:assets_investment].lookup),
        Dict(k => JuMP.value(v) for (k, v) in variables[:assets_investment_energy].lookup),
        Dict(k => JuMP.value(v) for (k, v) in variables[:flows_investment].lookup),
        JuMP.value.(variables[:storage_level_rep_period].container),
        JuMP.value.(variables[:storage_level_over_clustered_year].container),
        JuMP.value.(model[:max_energy_over_clustered_year]),
        JuMP.value.(model[:min_energy_over_clustered_year]),
        JuMP.value.(variables[:flow].container),
        JuMP.objective_value(model),
        dual_variables,
    )
end

"""
    compute_dual_variables(model)

Compute the dual variables for the given model.

If the model does not have dual variables, this function fixes the discrete variables, optimizes the model, and then computes the dual variables.

## Arguments
- `model`: The model for which to compute the dual variables.

## Returns
A named tuple containing the dual variables of selected constraints.
"""
function compute_dual_variables(model)
    try
        if !JuMP.has_duals(model)
            JuMP.fix_discrete_variables(model)
            JuMP.optimize!(model)
        end

        return Dict(
            :hub_balance => JuMP.dual.(model[:hub_balance]),
            :consumer_balance => JuMP.dual.(model[:consumer_balance]),
        )
    catch
        return nothing
    end
end
