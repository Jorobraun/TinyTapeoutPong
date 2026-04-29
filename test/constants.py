DEBUG = False
SCALE = 10
MAX_FPS = 60

# Set clock period to 40 ns (25 MHz)
CLOCK_PERIOD = 40

# Set VGA timing parameters matching hvsync_generator.v
H_DISPLAY = 96 # 640
H_FRONT   =  0 # 16
H_SYNC    =  0 # 96
H_BACK    = 0 # 48
V_DISPLAY = 64 #480
V_FRONT   =  0 #10
V_SYNC    =   0 # 2
V_BACK    =  0 # 33

# Derived constants
H_SYNC_START = H_DISPLAY + H_FRONT
H_SYNC_END = H_SYNC_START + H_SYNC
H_TOTAL = H_SYNC_END + H_BACK
V_SYNC_START = V_DISPLAY + V_FRONT
V_SYNC_END = V_SYNC_START + V_SYNC
V_TOTAL = V_SYNC_END + V_BACK