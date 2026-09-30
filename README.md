# Verilog Traffic Light Controller (FSM)

A synthesizable Finite State Machine (FSM) based Traffic Light Controller modeling a 4-way intersection (North-South main street and East-West side street).

---

## 🚦 System Architecture & State Machine

The controller operates as a 4-state Moore/Mealy hybrid FSM with glitch-free registered outputs:

```
        +-------------------------------------------------------------+
        |                                                             |
        v                                                             |
+---------------+       sensor_ew == 1        +---------------+       |
|  S_NS_GREEN   | --------------------------> |  S_NS_YELLOW  |       |
| NS: G, EW: R  |   (after NS_GREEN_CYCLES)   | NS: Y, EW: R  |       |
+---------------+                             +---------------+       |
        ^                                             |               |
        |                                             | (after        |
        | (after                                      |  YELLOW_TIME) |
        |  YELLOW_TIME)                               v               |
+---------------+                             +---------------+       |
|  S_EW_YELLOW  | <-------------------------- |  S_EW_GREEN   |       |
| NS: R, EW: Y  |   (after EW_GREEN_CYCLES)   | NS: R, EW: G  |       |
+---------------+                             +---------------+       |
        |                                                             |
        +-------------------------------------------------------------+
```

### Light Encoding (3-bit One-Hot)
Each direction output (`ns_lights`, `ew_lights`) is 3 bits wide:
- `3'b100` : **RED**
- `3'b010` : **YELLOW**
- `3'b001` : **GREEN**

Each bit can directly drive physical LEDs or I/O pins without external decoders.

---

## 📋 Module Ports & Parameters

### Parameters
| Parameter | Default | Description |
| :--- | :---: | :--- |
| `TIMER_WIDTH` | `6` | Bit-width for timer counter (expandable for FPGA clock dividers) |
| `NS_GREEN_CYCLES` | `10` | Duration of North-South Green phase |
| `NS_YELLOW_CYCLES` | `3` | Duration of North-South Yellow phase |
| `EW_GREEN_CYCLES` | `6` | Duration of East-West Green phase |
| `EW_YELLOW_CYCLES` | `3` | Duration of East-West Yellow phase |

### Port List
| Port | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | Master system clock |
| `rst_n` | Input | 1 | Active-low asynchronous reset |
| `enable` | Input | 1 | Clock enable / pause (1: run, 0: hold/freeze) |
| `sensor_ew` | Input | 1 | Side-street vehicle sensor (1: car waiting / demand, 0: idle) |
| `ns_lights` | Output | 3 | North-South light outputs `{RED, YELLOW, GREEN}` |
| `ew_lights` | Output | 3 | East-West light outputs `{RED, YELLOW, GREEN}` |
| `state` | Output | 2 | Current FSM state (`00`: NS_G, `01`: NS_Y, `10`: EW_G, `11`: EW_Y) |
| `timer_count`| Output | `TIMER_WIDTH` | Current phase elapsed cycle counter |

---

## ⚙️ Operating Modes

1. **Demand-Responsive Mode (`sensor_ew` dynamic)**:
   - North-South (Main street) remains **GREEN** indefinitely if no traffic is waiting on East-West.
   - Once a car arrives (`sensor_ew = 1`) and the minimum green time has elapsed, the controller transitions through Yellow to allow East-West traffic to pass.
2. **Fixed-Time Cyclic Mode (`sensor_ew` tied to `1'b1`)**:
   - The controller cycles continuously between North-South and East-West phases based strictly on configured timer values.

---

## 🧪 Simulation and Waveforms

### Run Simulation with Icarus Verilog:
```powershell
# Compile design and testbench
iverilog -o traffic_sim.vvp traffic_light_controller.v tb_traffic_light_controller.v

# Execute simulation
vvp traffic_sim.vvp
```

### View Waveforms in GTKWave:
The testbench generates `traffic_light_controller.vcd`:
```powershell
gtkwave traffic_light_controller.vcd
```
