# Streaming Convolution

This is a streaming convolutional engine written in SystemVerilog. It takes a
streamed raster image and performs a configurable convolution. The output of
the engine will be smaller then the original.


## Python Testbench Simulation

Testbenchs are being written for the SystemVerilog modules by leveraging the
[VPW](https://github.com/bmartini/vpw-testbench) and pytest frameworks and can
be found in the [dut](dut) directory.

To run a single test, use the following command.

```bash
pytest -v multiply_add.py
```

To run a single test within a testbench.

```bash
pytest -v multiply_add.py -k test_stream_contiguous_positive
```

And to run a every test within the current directory.

```bash
pytest -v *.py
```

If you want to generate a waveform to view for debug purposes you must edit the
following line within a testbench.

From:

```python
    vpw.init(design, trace=False)
```

To:

```python
    vpw.init(design, trace=True)
```

And then when you run a single test within that testbench, a waveform will be
created in the current directory.



## Formal Verification

Assertions are used to model the behavior of the modules for use in formal
verification. To preform the verification proof the open source software
[SymbiYosys](https://symbiyosys.readthedocs.io/en/latest/) and the
configuration files can be found in the [sby](sby) directory.


```bash
sby -f <module name>.sby
```
