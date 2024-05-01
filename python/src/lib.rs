use pyo3::prelude::*;
use pyo3::wrap_pyfunction;

#[pyfunction]
fn phonetic_cost(a: char, b: char) -> f32 {
    if a == b {
        return 0.0
    }
    match a {
        'a' => return 0.3
    }
    return 0.5
}

#[pymodule]
fun rust_extension(py: Python m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(phonetic_cost, m)?)?;
    Ok(())
}
