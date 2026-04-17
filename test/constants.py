
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