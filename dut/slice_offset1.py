"""
Testbench for slice module with offset parameter set to 1.
"""

import shutil
import tempfile
from enum import IntEnum
from typing import Final, Generator, List

import pytest
import vpw


class Param(IntEnum):
    """Module parameter configuration.

    Attributes
    MAC_NB: Number of multipliers in the module
    OFFSET: Number of pixels that belong to the 2nd clock
    WEIGHT_WIDTH: Bus width of kernel weight numbers
    IMAGE_WIDTH: Bus width of image numbers
    """
    MAC_NB = 3
    OFFSET = 1
    WEIGHT_WIDTH = 8
    IMAGE_WIDTH = 16


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
    width = Param.IMAGE_WIDTH + Param.WEIGHT_WIDTH
    mask = (1 << width) - 1

    m1 = _twos_extend(width, Param.IMAGE_WIDTH, m1)
    m2 = _twos_extend(width, Param.WEIGHT_WIDTH, m2)

    return (m1 * m2) & mask


def _mac_addition(addition: int, product: int) -> int:
    """Two's complement addition."""
    width_addition = Param.IMAGE_WIDTH + Param.WEIGHT_WIDTH + 1
    width_product = Param.IMAGE_WIDTH + Param.WEIGHT_WIDTH
    mask_addition = (1 << width_addition) - 1

    addition = _twos(width_addition, addition)
    product = _twos_extend(width_addition, width_product, product)

    return (addition + product) & mask_addition


class Checker:
    """Model of Hardware Module"""
    def __init__(self) -> None:
        self._reset: bool = False
        self._weight: List[int] = [0]*Param.MAC_NB
        self._result: int = 0
        self._partial: int = 0

    def _slice(self, image: List[int]) -> None:
        """Modeling the slice modules logic."""
        result = self._partial
        partial = 0

        for x in range(Param.MAC_NB):
            if (Param.OFFSET == 0) or (x < Param.OFFSET):
                result = _mac_addition(result, _mac_multiply(image[x], self._weight[x]))
            else:
                partial = _mac_addition(partial, _mac_multiply(image[x], self._weight[x]))

        self._result = result
        self._partial = partial

    def reset(self, state: bool) -> None:
        """Prep 'reset' module and model."""
        vpw.prep("rst", [int(state)])
        self._reset = state

    def send_weight(self, weight: List[int]) -> None:
        """Blocking function that sends a list of weights to module."""
        assert len(weight) == Param.MAC_NB, \
               f"Incorrect number of weights, given: {len(weight)}, expected: {Param.MAC_NB}"
        self._weight = weight

        for x, w in enumerate(weight):
            vpw.prep("weight", vpw.pack(Param.WEIGHT_WIDTH, w))
            vpw.prep("weight_valid", vpw.pack(Param.MAC_NB, 1 << x))
            vpw.tick()

        vpw.prep("weight", vpw.pack(Param.WEIGHT_WIDTH, 0))
        vpw.prep("weight_valid", vpw.pack(Param.MAC_NB, 0))
        vpw.tick()

    def prep_image(self, image: List[int]) -> None:
        """Prep stream values for the image bus."""
        assert len(image) == Param.MAC_NB, f"Incorrect number of pixels, given: {len(image)}, expected: {Param.MAC_NB}"

        image_bus = 0
        for x, i in enumerate(image):
            image_bus = image_bus | (i << (x*Param.IMAGE_WIDTH))

        vpw.prep("image", vpw.pack(Param.IMAGE_WIDTH*Param.MAC_NB, image_bus))
        vpw.prep("image_valid", [1])

        self._slice(image)

    def init(self, _) -> Generator:
        """Background initilization function."""
        PIPELINE: Final = 18

        result_1m = 0
        result = 0
        result_p = [0]*PIPELINE
        self._result = 0

        while True:
            io = yield
            assert io["result"] == result, f"{result_1m}, {result}, {result_p}"

            result_1m = result
            result = result_p[0]
            result_p = result_p[1::]+[self._result]
            self._result = 0

            vpw.prep("image", vpw.pack(Param.IMAGE_WIDTH*Param.MAC_NB, 0))
            vpw.prep("image_valid", [0])

            if self._reset:
                result_1m = 0
                result = 0
                result_p = [0]*PIPELINE
                self._weight = [0]*Param.MAC_NB
                self._partial = 0


@pytest.fixture(name="_design", scope="module")
def design():
    """Compile the design only once for all tests."""
    workspace = tempfile.mkdtemp()

    dut = vpw.create(module='slice',
                     clock='clk',
                     include=['../hdl'],
                     parameter={'MAC_NB': Param.MAC_NB,
                                'OFFSET': Param.OFFSET,
                                'WEIGHT_WIDTH': Param.WEIGHT_WIDTH,
                                'IMAGE_WIDTH': Param.IMAGE_WIDTH},
                     workspace=workspace)
    yield dut

    shutil.rmtree(workspace)


@pytest.fixture(name="_context")
def context(_design):
    """Setup and tear-down the design for each test."""
    vpw.init(_design, trace=False)

    vpw.prep("rst", [1])
    vpw.prep("weight", vpw.pack(Param.WEIGHT_WIDTH, 0))
    vpw.prep("weight_valid", vpw.pack(Param.MAC_NB, 0))
    vpw.prep("image", vpw.pack(Param.IMAGE_WIDTH*Param.MAC_NB, 0))
    vpw.prep("image_valid", [0])
    vpw.idle(2)
    vpw.prep("rst", [0])
    vpw.idle(2)

    yield

    vpw.idle(10)
    vpw.finish()


def test_stream_contiguous_2_beats(_context):
    """Test sending 2 contiguous beats of the image stream."""
    checker = Checker()
    vpw.register(checker)

    # send weights to module
    weight = [2]*Param.MAC_NB
    checker.send_weight(weight)
    vpw.idle(4)

    # prep image
    image = [x+1 for x in range(Param.MAC_NB)]
    checker.prep_image(image)
    vpw.tick()

    image = [x+1+Param.MAC_NB for x in range(Param.MAC_NB)]
    checker.prep_image(image)
    vpw.tick()

    vpw.idle(100)  # wait for longer then the pipelined depth of module


def test_stream_intermittent_2_beats(_context):
    """Test sending 2 non-contiguous beats of the image stream."""
    checker = Checker()
    vpw.register(checker)

    # send weights to module
    weight = [2]*Param.MAC_NB
    checker.send_weight(weight)

    # prep image
    image = [x+1 for x in range(Param.MAC_NB)]
    checker.prep_image(image)
    vpw.idle(10)

    image = [x+1+Param.MAC_NB for x in range(Param.MAC_NB)]
    checker.prep_image(image)
    vpw.tick()

    vpw.idle(100)  # wait for longer then the pipelined depth of module
