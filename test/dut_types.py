# Dieses File ist nur da, damit Pylance besser cocotb autocompleten kann und besser Versteht was die typen sind.

from cocotb.handle import HierarchyObject
from cocotb.handle import LogicObject, LogicArrayObject

class DUT(HierarchyObject):
    ena: LogicObject
    ui_in: LogicObject
    uio_in: LogicObject
    uo_out: LogicArrayObject
    rst_n: LogicObject
    clk: LogicObject