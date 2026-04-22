import threading
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import debugpy
import pygame
import itertools
import queue
from PIL import Image
from pygame.key import ScancodeWrapper
from test.constants import *
from test.dut_types import DUT

# Palette mapping remains unchanged
PALETTE = [bytes(3)] * 256
for r1, r0, g1, g0, b1, b0 in itertools.product(range(2), repeat=6):
    red = 170*r1 + 85*r0
    green = 170*g1 + 85*g0
    blue = 170*b1 + 85*b0
    color_index = b0<<6|g0<<5|r0<<4|b1<<2|g1<<1|r1<<0
    for sync_bits in (0x00, 0x08, 0x80, 0x88):
        PALETTE[color_index | sync_bits] = bytes((red, green, blue))

# Helper functions (capture_line, capture_frame, etc.) remain the same
async def capture_line(dut : DUT, framebuffer, offset, check_sync) -> None:
    for i in range(H_DISPLAY):
        framebuffer[offset+3*i:offset+3*i+3] = PALETTE[int(dut.uo_out.value)]
        await ClockCycles(dut.clk, 1)
    await ClockCycles(dut.clk, H_TOTAL - H_DISPLAY)

async def capture_frame(dut: DUT, frame_num, check_sync=True) -> Image.Image:
    framebuffer = bytearray(V_DISPLAY*H_DISPLAY*3)
    for j in range(V_DISPLAY):
        await capture_line(dut, framebuffer, 3*j*H_DISPLAY, check_sync)
    await ClockCycles(dut.clk, H_TOTAL*(V_TOTAL-V_DISPLAY))
    return Image.frombytes('RGB', (H_DISPLAY, V_DISPLAY), bytes(framebuffer))

async def set_inputs(dut: DUT) -> None:
    # This call will now work because pygame.init() happened in the main thread
    pygame.event.pump() # Process internal pygame events
    keys: ScancodeWrapper = pygame.key.get_pressed()

    key_effect: dict[int, int] = {
        pygame.K_a : 0, pygame.K_d : 1,
        pygame.K_j : 2, pygame.K_l : 3
    }

    value = 0
    for key, bit in key_effect.items():
        if keys[key]:
            value |= (1 << bit)

    dut.ui_in.value = value

def pygame_thread(images_queue: queue.Queue, stop_event: threading.Event) -> None:
    """ This thread now ONLY handles rendering the window surface. """
    window: pygame.Surface = pygame.display.set_mode((H_DISPLAY * SCALE, V_DISPLAY * SCALE))
    pygame.display.set_caption("Tiny Tapeout Pong")
    clock_py = pygame.time.Clock()

    while not stop_event.is_set():
        # Handle Window Close event in the UI thread
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                stop_event.set()
                return

        try:
            image: pygame.Surface = images_queue.get_nowait()
            window.fill(pygame.Color(0, 0, 0)) # Clean background
            scaled_image = pygame.transform.scale_by(image, SCALE)
            window.blit(scaled_image, (0, 0))
            pygame.display.flip()
        except queue.Empty:
            pass
        
        clock_py.tick(MAX_FPS)

@cocotb.test()
async def test_project(dut: DUT) -> None:
    # --- STEP 1: INITIALIZE PYGAME IN MAIN CONTEXT ---
    pygame.init()
    # -------------------------------------------------

    if DEBUG:
        debugpy.listen(("0.0.0.0", 5678))
        print("Warte auf Debugger an Port 5678...")
        debugpy.wait_for_client()

    # Clock setup
    clock = Clock(dut.clk, CLOCK_PERIOD, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    images_queue: queue.Queue = queue.Queue(maxsize=1)
    stop_event = threading.Event()

    # Start the UI thread
    ui_thread = threading.Thread(target=pygame_thread, args=(images_queue, stop_event,))
    ui_thread.start()

    try:
        for i in itertools.count():
            await set_inputs(dut)

            frame: Image.Image = await capture_frame(dut, i, False)
            
            if stop_event.is_set():
                break

            # Convert PIL image to Pygame surface and send to UI thread
            img_surface: pygame.Surface = pygame.image.fromstring(
                frame.tobytes(), frame.size, "RGB"
            ).convert()
            
            try:
                images_queue.put_nowait(img_surface)
            except queue.Full:
                pass # Skip frame if UI thread is busy

    finally:
        stop_event.set()
        ui_thread.join()
        pygame.quit()