import numpy as np
import matplotlib.pyplot as plt


class PID:
    def __init__(
        self,
        kp: float,
        kv: float,
        ki: float,
        kd: float,
        kvff: float,
        kaff: float,
        kpff1: float,
        kpff0: float,
        dt: float,
        ff: bool,
        out_lim: tuple[float, float] | None = None
    ) -> None:
        self.kp = kp
        self.kv = kv
        self.ki = ki
        self.kd = kd
        self.kvff = kvff
        self.kaff = kaff
        self.kpff1 = kpff1
        self.kpff0 = kpff0
        self.dt = dt
        self.ff = ff
        self.inv_dt = 1.0 / dt
        self.prev_error = 0
        self.prev_process_variable = 0
        self.prev_velocity_desired = 0
        self.prev_setpoint = 0
        self.integral = 0.0
        self.output_limits = out_lim

    def update(self, setpoint: int, process_variable: int) -> int:
        error = setpoint - process_variable
        velocity = (process_variable - self.prev_process_variable) * self.inv_dt
        velocity_desired = int((setpoint - self.prev_setpoint) * self.inv_dt)

        self.integral += error * self.dt
        derivative = (error - self.prev_error) * self.inv_dt

        if not self.ff:
            ff = 0
        else:
            ff = (
                self.kvff * velocity_desired +
                self.kaff * (velocity_desired - self.prev_velocity_desired) +
                self.kpff1 * setpoint +
                self.kpff0 * abs(setpoint) * setpoint
            )

        pid_sum = int(
            self.kp * error -
            self.kv * velocity +
            self.ki * self.integral +
            self.kd * derivative +
            ff
        )

        self.prev_error = error
        self.prev_process_variable = process_variable
        self.prev_velocity_desired = velocity_desired
        self.prev_setpoint = setpoint

        if self.output_limits is not None:
            lo, hi = self.output_limits
            pid_sum = max(lo, min(hi, pid_sum))

        return pid_sum


def trapezoid_wave_rest(t, T_ramp, T_hold, T_rest, A):
    period = 2 * (2 * T_ramp + T_hold) + T_rest
    phase = np.mod(t, period)
    y = np.zeros_like(t, dtype=float)

    m1 = phase < T_ramp
    y[m1] = A * phase[m1] / T_ramp

    m2 = (phase >= T_ramp) & (phase < T_ramp + T_hold)
    y[m2] = A

    m3 = (phase >= T_ramp + T_hold) & (phase < 2 * T_ramp + T_hold)
    y[m3] = A * (1 - (phase[m3] - T_ramp - T_hold) / T_ramp)

    rest_start = 2 * T_ramp + T_hold
    rest_end = rest_start + T_rest
    m_rest = (phase >= rest_start) & (phase < rest_end)
    y[m_rest] = 0

    neg_start = rest_end
    p = phase - neg_start

    n1 = (phase >= neg_start) & (phase < neg_start + T_ramp)
    y[n1] = -A * p[n1] / T_ramp

    n2 = (phase >= neg_start + T_ramp) & (phase < neg_start + T_ramp + T_hold)
    y[n2] = -A

    n3 = (phase >= neg_start + T_ramp + T_hold) & (phase < neg_start + 2 * T_ramp + T_hold)
    y[n3] = -A * (1 - (p[n3] - T_ramp - T_hold) / T_ramp)

    return y


pid_kwargs = {
    "kp": 0.004,
    "kv": 0.9,
    "ki": 0.0002,
    "kd": 0,
    "kvff": 3.7,
    "kaff": 100,
    "kpff1": 0.00196,
    "kpff0": 0,
    "dt": 1 / 20000,
    "ff": True,
    "out_lim": None,
}

pid = PID(**pid_kwargs)

fs = 20000
dt = 1 / fs
duration = 2 * (2 * 6.0 + 1.0 + 1.0)

t = np.arange(0, duration, dt)

A = 5e5
T_ramp = 6.0
T_hold = 1.0
T_rest = 1.0

setpoints = trapezoid_wave_rest(t, T_ramp, T_hold, T_rest, A)
setpoint = np.round(setpoints).astype(int)

process_variable = np.full_like(t, 100, dtype=int)
pid_sum = np.zeros_like(t, dtype=float)

for i in range(len(t)):
    pid_sum[i] = pid.update(setpoint[i], int(process_variable[i]))

plt.figure()
plt.plot(t, pid_sum, label="PID Output")
plt.plot(t, setpoint, label="Setpoint")
plt.plot(t, process_variable, label="Real Input")
plt.grid(color="grey", linewidth=0.5)
plt.minorticks_on()
plt.grid(which="major", color="grey", linewidth=0.8)
plt.grid(which="minor", color="grey", linewidth=0.15)
plt.legend()
plt.text(
    0.02,
    0.02,
    "\n".join(f"{k}: {v}" for k, v in pid_kwargs.items()),
    transform=plt.gca().transAxes,
    ha="left",
    va="bottom",
    bbox=dict(boxstyle="round", facecolor="white", alpha=0.8)
)
plt.xlabel("Time [s]")
plt.ylabel("Position")
plt.title("PID demo at 20 kHz")
plt.show()