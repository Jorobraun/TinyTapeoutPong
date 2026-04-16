import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import debugpy
import pygame

import itertools
from PIL import Image, ImageChops

DEBUG = False

# Set clock period to 40 ns (25 MHz)
CLOCK_PERIOD = 40

# Set VGA timing parameters matching hvsync_generator.v
H_DISPLAY = 640
H_FRONT   =  16
H_SYNC    =  96
H_BACK    =  48
V_DISPLAY = 480
V_FRONT   =  10
V_SYNC    =   2
V_BACK    =  33

# Number of frames to capture
CAPTURE_FRAMES = 3

# Derived constants
H_SYNC_START = H_DISPLAY + H_FRONT
H_SYNC_END = H_SYNC_START + H_SYNC
H_TOTAL = H_SYNC_END + H_BACK
V_SYNC_START = V_DISPLAY + V_FRONT
V_SYNC_END = V_SYNC_START + V_SYNC
V_TOTAL = V_SYNC_END + V_BACK

# Palette mapping uo_out values to RGB color
# uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}
# Some Optimisation
PALETTE = [bytes(3)] * 256
for r1, r0, g1, g0, b1, b0 in itertools.product(range(2), repeat=6):
    red = 170*r1 + 85*r0
    green = 170*g1 + 85*g0
    blue = 170*b1 + 85*b0
    color_index = b0<<6|g0<<5|r0<<4|b1<<2|g1<<1|r1<<0
    for sync_bits in (0x00, 0x08, 0x80, 0x88):
        PALETTE[color_index | sync_bits] = bytes((red, green, blue))


# Define some functions for capturing lines & frames
async def check_line(dut, expected_vsync) -> None:
    for i in range(H_TOTAL):
        hsync = int(dut.uo_out.value[7])
        vsync = int(dut.uo_out.value[3])
        assert hsync == (0 if H_SYNC_START <= i < H_SYNC_END else 1), "Unexpected hsync pattern"
        assert vsync == expected_vsync, "Unexpected vsync pattern"
        await ClockCycles(dut.clk, 1)

async def capture_line(dut, framebuffer, offset, check_sync) -> None:
    if check_sync:
        for i in range(H_TOTAL):
            hsync = int(dut.uo_out.value[7])
            vsync = int(dut.uo_out.value[3])
            assert hsync == (0 if H_SYNC_START <= i < H_SYNC_END else 1), "Unexpected hsync pattern"
            assert vsync == 1, "Unexpected vsync pattern"
            if i < H_DISPLAY:
                framebuffer[offset+3*i:offset+3*i+3] = PALETTE[int(dut.uo_out.value)]
            await ClockCycles(dut.clk, 1)
    else: # Small Optimasation
        for i in range(H_DISPLAY):
            framebuffer[offset+3*i:offset+3*i+3] = PALETTE[int(dut.uo_out.value)]
            await ClockCycles(dut.clk, 1)

        await ClockCycles(dut.clk, H_TOTAL - H_DISPLAY)

async def skip_frame(dut, frame_num) -> None:
    dut._log.info(f"Skipping frame {frame_num}")
    await ClockCycles(dut.clk, H_TOTAL*V_TOTAL)

async def capture_frame(dut, frame_num, check_sync=True) -> Image.Image:
    framebuffer = bytearray(V_DISPLAY*H_DISPLAY*3)
    for j in range(V_DISPLAY):
        dut._log.info(f"Frame {frame_num}, line {j} (display)")
        line = await capture_line(dut, framebuffer, 3*j*H_DISPLAY, check_sync)
    if check_sync:
        for j in range(j, j+V_FRONT):
            dut._log.info(f"Frame {frame_num}, line {j} (front porch)")
            await check_line(dut, 1)
        for j in range(j, j+V_SYNC):
            dut._log.info(f"Frame {frame_num}, line {j} (sync pulse)")
            await check_line(dut, 0)
        for j in range(j, j+V_BACK):
            dut._log.info(f"Frame {frame_num}, line {j} (back porch)")
            await check_line(dut, 1)
    else:
        dut._log.info(f"Frame {frame_num}, skipping non-display lines")
        await ClockCycles(dut.clk, H_TOTAL*(V_TOTAL-V_DISPLAY))
    frame = Image.frombytes('RGB', (H_DISPLAY, V_DISPLAY), bytes(framebuffer))
    return frame

async def set_input();

@cocotb.test()
async def test_project(dut):
    print(type(dut))

    # Wichtig für Debug in VSCode
    if DEBUG:
        debugpy.listen(("0.0.0.0", 5678))
        print("Warte auf Debugger an Port 5678...")
        debugpy.wait_for_client()

    # Set up the clock
    clock = Clock(dut.clk, CLOCK_PERIOD, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset the design
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    pygame.init()
    window: pygame.Surface = pygame.display.set_mode((H_DISPLAY, V_DISPLAY))
    clock_py = pygame.time.Clock()

    for i in itertools.count():
        frame: Image.Image = await capture_frame(dut, i, False)
        image: pygame.Surface = pygame.image.fromstring(frame.tobytes(), frame.size, frame.mode).convert()

        # Eventhandling
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return 0

        window.fill(pygame.Color(0, 0, 255))
        window.blit(image, image.get_rect())

        pygame.display.flip()
        clock_py.tick(60)
