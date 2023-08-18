"""
Testbench for multiply_add module.
"""

import random
import shutil
import tempfile
from enum import IntEnum
from typing import Generator

import pytest
import vpw


class Param(IntEnum):
    """Module parameter configuration.

    Attributes
    M1_WIDTH: Bus width of 'm1' data
    M2_WIDTH: Bus width of 'm2' data
    """
    M1_WIDTH = 16
    M2_WIDTH = 16


def _twos(width: int, data: int) -> int:
    """Convert signed numbers into two's complement.

    If a number sent in as a negatively signed int it will be converted to a
    two's complement negative number with a defined bit width. Otherwise the
    number is masked to not extra bits are expressed in the returned number.

    Arguments
    width: Number of bits used to express the data value
    data: The number to be converted to two's complement
    """
    mask = (1 << width) - 1

    if data < 0:
        data = data + 2**width

    return data & mask


def _twos_extend(extend_width: int, data_width: int, data: int) -> int:
    """Extend signed bit of a two's complement number.

    Before performing an operation on a twos complement number its width must
    be extended to be the same as the finial operator.

    Arguments
    extend_width: Number of bits used to express the extended data value
    data_width: Number of bits used to express the data value
    data: The number to be converted to two's complement
    """
    mask_data = (1 << data_width) - 1
    mask_extend = (1 << extend_width) - 1
    negative = 1 << (data_width - 1)

    data = _twos(data_width, data)

    if bool(data & negative):
        data = (mask_extend ^ mask_data) | data

    return data


def _mac_multiply(m1: int, m2: int) -> int:
    """Two's complement multiply."""
    width = Param.M1_WIDTH + Param.M2_WIDTH
    mask = (1 << width) - 1

    m1 = _twos_extend(width, Param.M1_WIDTH, m1)
    m2 = _twos_extend(width, Param.M2_WIDTH, m2)

    return (m1 * m2) & mask


def _mac_addition(addition: int, product: int) -> int:
    """Two's complement addition."""
    width_addition = Param.M1_WIDTH + Param.M2_WIDTH + 1
    width_product = Param.M1_WIDTH + Param.M2_WIDTH
    mask_addition = (1 << width_addition) - 1

    addition = _twos(width_addition, addition)
    product = _twos_extend(width_addition, width_product, product)

    return (addition + product) & mask_addition


class Checker:
    """Model of Hardware Module"""
    def __init__(self) -> None:
        self._reset: bool = False
        self._result: int = 0

    def reset(self, state: bool) -> None:
        """Prep 'reset' module and model."""
        vpw.prep("rst", [int(state)])
        self._reset = state

    def set(self, m1: int, m2: int, add: int) -> None:
        """Prep 'm2', 'm1', and 'addition' in module and model."""
        vpw.prep("m2", vpw.pack(Param.M2_WIDTH, m2))
        vpw.prep("m1", vpw.pack(Param.M1_WIDTH, m1))
        vpw.prep("add", vpw.pack(Param.M1_WIDTH + Param.M2_WIDTH + 1, add))
        self._result = _mac_addition(add, _mac_multiply(m1, m2))

    def init(self, _) -> Generator:
        """Background initilization function."""
        result_1m = 0
        result = 0
        result_1p = 0
        result_2p = 0
        result_3p = 0
        result_4p = 0
        self._result = 0

        while True:
            io = yield
            assert io["result"] == result, f"{result_1m}, {result_4p}"

            result_1m = result
            result = result_1p
            result_1p = result_2p
            result_2p = result_3p
            result_3p = result_4p
            result_4p = self._result

            self._result = 0
            vpw.prep("m2", vpw.pack(Param.M2_WIDTH, 0))
            vpw.prep("m1", vpw.pack(Param.M1_WIDTH, 0))
            vpw.prep("add", vpw.pack(Param.M1_WIDTH + Param.M2_WIDTH + 1, 0))

            if self._reset:
                result = 0
                result_1p = 0
                result_2p = 0
                result_3p = 0
                result_4p = 0


@pytest.fixture(name="_design", scope="module")
def design():
    """Compile the design only once for all tests."""
    workspace = tempfile.mkdtemp()

    dut = vpw.create(module='multiply_add',
                     clock='clk',
                     include=['../hdl'],
                     parameter={'M1_WIDTH': Param.M1_WIDTH,
                                'M2_WIDTH': Param.M2_WIDTH},
                     workspace=workspace)
    yield dut

    shutil.rmtree(workspace)


@pytest.fixture(name="_context")
def context(_design):
    """Setup and tear-down the design for each test."""
    vpw.init(_design, trace=False)

    vpw.prep("rst", [1])
    vpw.prep("m2", vpw.pack(Param.M2_WIDTH, 0))
    vpw.prep("m1", vpw.pack(Param.M1_WIDTH, 0))
    vpw.prep("add", vpw.pack(Param.M2_WIDTH, 0))
    vpw.idle(2)
    vpw.prep("rst", [0])
    vpw.idle(2)

    yield

    vpw.idle(10)
    vpw.finish()


def test_pipeline_depth(_context):
    """Test that module pipeline depth is 5 clock cycles deep."""
    vpw.prep("m2", vpw.pack(Param.M2_WIDTH, 1))
    vpw.prep("m1", vpw.pack(Param.M1_WIDTH, 5))
    vpw.prep("add", vpw.pack(Param.M1_WIDTH, 0))
    vpw.tick()
    vpw.prep("m1", vpw.pack(Param.M1_WIDTH, 0))
    vpw.prep("m2", vpw.pack(Param.M2_WIDTH, 0))
    vpw.prep("add", vpw.pack(Param.M2_WIDTH, 0))

    io = vpw.idle(4)
    assert io["result"] == 0, "Module is 4 clock cycles deep instead of 5."

    io = vpw.tick()
    assert io["result"] == 5, "Module should be 5 clocks cycles deep."


def test_stream_contiguous_positive(_context):
    """Test contiguous stream with both 'm1' and 'm2' positive numbers."""
    checker = Checker()
    vpw.register(checker)

    for x in range(10):
        checker.set(1, x + 1, 0)
        vpw.tick()

    vpw.idle(10)  # wait for longer then the pipelined depth of module


def test_stream_contiguous_negative(_context):
    """Test contiguous stream with 'm1' positive and 'm2' negative numbers."""
    checker = Checker()
    vpw.register(checker)

    for x in range(10):
        checker.set(-1, x + 1, 0)
        vpw.tick()

    vpw.idle(10)  # wait for longer then the pipelined depth of module


def test_stream_contiguous_negative_double(_context):
    """Test contiguous stream with both 'm1' and 'm2' negative numbers."""
    checker = Checker()
    vpw.register(checker)

    for x in range(-1, -11, -1):
        checker.set(-1, x, 0)
        vpw.tick()

    vpw.idle(10)  # wait for longer then the pipelined depth of module


def test_stream_intermittent(_context):
    """Test intermittent stream."""
    checker = Checker()
    vpw.register(checker)

    data = [x + 1 for x in range(10)]

    while data:
        if bool(random.getrandbits(1)):
            m1 = data.pop(0)
            checker.set(1, m1, 0)

        vpw.tick()

    vpw.idle(10)  # wait for longer then the pipelined depth of module


def test_stream_reset(_context):
    """Test when a reset signal is sent during streaming."""
    checker = Checker()
    vpw.register(checker)

    for x in [1, 2, 3, 4, 5]:
        checker.set(1, x, 0)
        vpw.tick()

    checker.reset(True)
    checker.set(1, 6, 0)
    vpw.tick()

    checker.reset(False)
    for x in [7, 8, 9, 10]:
        checker.set(1, x, 0)
        vpw.tick()

    vpw.idle(10)  # wait for longer then the pipelined depth of module


def test_stream_random(_context):
    """Test many random numbers for both 'm1' and 'm2'."""
    checker = Checker()
    vpw.register(checker)

    for _ in range(5000):
        checker.set(random.getrandbits(Param.M2_WIDTH), random.getrandbits(Param.M1_WIDTH), 0)
        vpw.tick()

    vpw.idle(10)  # wait for longer then the pipelined depth of module
