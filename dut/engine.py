"""
Testbench for engine module.
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
    WEIGHT_WIDTH: Number width of kernel weight
    IMAGE_WIDTH: Number width of image
    IMAGE_NB: Number of pixels in image bus.
    KERNEL_WIDTH: The width of the convolutional kernel
    KERNEL_HEIGHT: The height of the convolutional kernel
    """
    WEIGHT_WIDTH = 8
    IMAGE_WIDTH = 16
    IMAGE_NB = 3
    KERNEL_WIDTH = 3
    KERNEL_HEIGHT = 3


WORD_WIDTH = Param.IMAGE_WIDTH*Param.IMAGE_NB
RESULT_WIDTH = Param.IMAGE_WIDTH+Param.WEIGHT_WIDTH+1
KERNEL_NB = Param.KERNEL_WIDTH*Param.KERNEL_HEIGHT


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


def _group_add(args: List[int]) -> int:
    """Two's complement group addition."""
    width_sum = RESULT_WIDTH + 2
    mask = (1 << RESULT_WIDTH) - 1

    args = [_twos_extend(width_sum, RESULT_WIDTH, a) for a in args]

    return sum(args) & mask


def _rescale(number: int, shift: int) -> int:
    """Bounded rescale a fixed point number."""
    num_mask = (1 << RESULT_WIDTH) - 1
    negative = 1 << (RESULT_WIDTH - 1)
    img_max = int((1 << (Param.IMAGE_WIDTH - 1)) - 1)
    img_min = int((img_max + 1) * -1)

    # converts to twos complement of defined width
    number = _twos(RESULT_WIDTH, number)

    # convert number back into negative when down stream should be negative
    if (number & negative) != 0 and RESULT_WIDTH >= (Param.IMAGE_WIDTH + shift):
        number = int((num_mask - number + 1) * -1)

    # raw value of shifted number
    scaled = _twos(Param.IMAGE_WIDTH, (number >> shift))

    if int(number >> shift) > img_max:
        # shifted number greater than image max
        scaled = _twos(Param.IMAGE_WIDTH, img_max)

    if int(number >> shift) < img_min:
        # shifted number less than image min
        scaled = _twos(Param.IMAGE_WIDTH, img_min)

    return scaled


class Checker:
    """Model of Hardware Module"""
    def __init__(self) -> None:
        self._reset: bool = False
        self._shift: int = 0
        self._weight: List[int] = [0]*KERNEL_NB
        self._result: int = 0

        self._slice_result: List[List[int]] = [[0]*Param.KERNEL_HEIGHT for _ in range(Param.IMAGE_NB)]
        self._slice_partial: List[List[int]] = [[0]*Param.KERNEL_HEIGHT for _ in range(Param.IMAGE_NB)]

    def _slice(self, image: List[int], height: int, position: int) -> None:
        """Modeling the slice modules logic."""
        offset = position if position < Param.KERNEL_WIDTH-1 else Param.KERNEL_WIDTH-1

        image = image*2
        image = image[offset+1:offset+Param.KERNEL_WIDTH+1:]

        weight = self._weight[height*Param.KERNEL_WIDTH:height*Param.KERNEL_WIDTH+3:]

        result = self._slice_partial[position][height]
        partial = 0

        for x in range(Param.KERNEL_WIDTH):
            if (offset == (Param.KERNEL_WIDTH-1)) or ((Param.KERNEL_WIDTH-1-offset) <= x):
                result = _mac_addition(result, _mac_multiply(image[x], weight[x]))
            else:
                partial = _mac_addition(partial, _mac_multiply(image[x], weight[x]))

        self._slice_result[position][height] = result
        self._slice_partial[position][height] = partial

    def reset(self, state: bool) -> None:
        """Prep 'reset' module and model."""
        vpw.prep("rst", [int(state)])
        self._reset = state

    def send_shift(self, shift: int) -> None:
        """Blocking function that sends the configuration value for the rescale module."""
        mask = (1 << 7) - 1
        self._shift = shift & mask
        assert self._shift == shift, "shift value too large for the configuration bus."

        vpw.prep("cfg_shift", [shift])
        vpw.prep("cfg_valid", [1])
        vpw.tick()

        vpw.prep("cfg_shift", [0])
        vpw.prep("cfg_valid", [0])
        vpw.tick()

    def send_weight(self, weight: List[int]) -> None:
        """Blocking function that sends a list of weights to module."""
        assert len(weight) == KERNEL_NB, f"Incorrect number of weights, given: {len(weight)}, expected: {KERNEL_NB}"
        self._weight = weight

        for w in weight:
            vpw.prep("weight", vpw.pack(Param.WEIGHT_WIDTH, w))
            vpw.prep("weight_valid", [1])
            vpw.tick()

        vpw.prep("weight", vpw.pack(Param.WEIGHT_WIDTH, 0))
        vpw.prep("weight_valid", [0])
        vpw.tick()

    def prep_image(self, image: List[int]) -> None:
        """Prep stream values for the image bus."""
        assert len(image) == Param.KERNEL_HEIGHT*Param.IMAGE_NB, \
               f"Incorrect number of pixels, given: {len(image)}, expected: {Param.KERNEL_HEIGHT*Param.IMAGE_NB}"

        image_bus = 0
        for x, i in enumerate(image):
            image_bus = image_bus | (i << (x*Param.IMAGE_WIDTH))

        vpw.prep("image", vpw.pack(Param.KERNEL_HEIGHT*WORD_WIDTH, image_bus))
        vpw.prep("image_valid", [1])

        for h in range(Param.KERNEL_HEIGHT):
            for s in range(Param.IMAGE_NB):
                self._slice(image, h, s)

        self._result = 0
        for x, column in enumerate(self._slice_result):
            self._result = self._result | (_rescale(_group_add(column), self._shift) << (x*Param.IMAGE_WIDTH))

    def init(self, _) -> Generator:
        """Background initilization function."""
        PIPELINE: Final = 28

        result_1m = 0
        result = 0
        result_p = [0]*PIPELINE
        self._result = 0

        while True:
            io = yield
            hw_result = vpw.unpack(WORD_WIDTH, io["result"])
            assert hw_result == result, f"{result_1m:x}, {hw_result:x} != {result:x}, {result_p}"

            result_1m = result
            result = result_p[0]
            result_p = result_p[1::]+[self._result]
            self._result = 0

            vpw.prep("image", vpw.pack(Param.IMAGE_WIDTH*Param.IMAGE_NB, 0))
            vpw.prep("image_valid", [0])

            if self._reset:
                result_1m = 0
                result = 0
                result_p = [0]*PIPELINE
                self._weight = [0]*KERNEL_NB
                self._slice_result = [[0]*Param.KERNEL_HEIGHT for _ in range(Param.IMAGE_NB)]
                self._slice_partial = [[0]*Param.KERNEL_HEIGHT for _ in range(Param.IMAGE_NB)]


@pytest.fixture(name="_design", scope="module")
def design():
    """Compile the design only once for all tests."""
    workspace = tempfile.mkdtemp()

    dut = vpw.create(module='engine',
                     clock='clk',
                     include=['../hdl'],
                     parameter={'WEIGHT_WIDTH': Param.WEIGHT_WIDTH,
                                'IMAGE_WIDTH': Param.IMAGE_WIDTH,
                                'IMAGE_NB': Param.IMAGE_NB,
                                'KERNEL_WIDTH': Param.KERNEL_WIDTH,
                                'KERNEL_HEIGHT': Param.KERNEL_HEIGHT},
                     workspace=workspace)
    yield dut

    shutil.rmtree(workspace)


@pytest.fixture(name="_context")
def context(_design):
    """Setup and tear-down the design for each test."""
    vpw.init(_design, trace=False)

    vpw.prep("rst", [1])
    vpw.prep("weight", vpw.pack(Param.WEIGHT_WIDTH, 0))
    vpw.prep("weight_valid", [0])
    vpw.prep("image", vpw.pack(Param.KERNEL_HEIGHT*WORD_WIDTH, 0))
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
    weight = [1]*KERNEL_NB
    #weight = [x+1 for x in range(KERNEL_NB)]
    checker.send_weight(weight)
    vpw.idle(4)

    # prep image
    image = [x+1 for x in range(Param.IMAGE_NB)]*Param.KERNEL_HEIGHT
    checker.prep_image(image)
    vpw.tick()

    image = [x+1+Param.IMAGE_NB for x in range(Param.IMAGE_NB)]*Param.KERNEL_HEIGHT
    checker.prep_image(image)
    vpw.tick()

    vpw.idle(50)  # wait for longer then the pipelined depth of module


def test_stream_intermittent_2_beats(_context):
    """Test sending 2 non-contiguous beats of the image stream."""
    checker = Checker()
    vpw.register(checker)

    # send weights to module
    weight = [1]*KERNEL_NB
    #weight = [x+1 for x in range(KERNEL_NB)]
    checker.send_weight(weight)
    vpw.idle(4)

    # prep image
    image = [x+1 for x in range(Param.IMAGE_NB)]*Param.KERNEL_HEIGHT
    checker.prep_image(image)
    vpw.idle(10)

    image = [x+1+Param.IMAGE_NB for x in range(Param.IMAGE_NB)]*Param.KERNEL_HEIGHT
    checker.prep_image(image)
    vpw.tick()

    vpw.idle(50)  # wait for longer then the pipelined depth of module
