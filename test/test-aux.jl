# file with auxiliary functions for the testing

function _read_csv_folder(connection, input_dir)
    schemas = TulipaEnergyModel.schema_per_table_name
    return TulipaIO.read_csv_folder(connection, input_dir; schemas)
end