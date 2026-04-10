import numpy as np  # Optional, for simulations
import matplotlib.pyplot as plt

class PID:
    def __init__(
            self, 
            kp: float,
            ki: float,
            kd: float,
            kff: float,
            dt: float,
            out_lim: tuple[float, float] | None = None
        ) -> None:

        self.kp: float = kp              
        self.ki: float = ki              
        self.kd: float = kd              
        self.kff: float = kff            
        self.dt: float = dt            
        self.inv_dt: float = 1.0 / dt
        self.prev_error: int = 0
        self.integral: float = 0.0
        self.output_limits: tuple[float, float] | None = out_lim
    
    def update(self, setpoint: int, process_variable: int, feedforward: int) -> int:
        """
        Calculate the next value out the PID.        
        """

        error = setpoint - process_variable

        self.integral += error * self.dt
        derivative = (error - self.prev_error) * self.inv_dt

        pid_sum = int(self.kp * error +
                  self.ki * self.integral +
                  self.kd * derivative +
                  self.kff * feedforward)
        self.prev_error = error

        if self.output_limits is not None:
           lo, hi = self.output_limits
           pid_sum = max(lo, min(hi, pid_sum))

        return pid_sum


pid_kwargs = {
    "kp": 1.3,
    # "ki": 0.001,
    "ki": 0.01,
    "kd": 0,
    "kff": 0,
    "dt": 0.1,
    "out_lim": None,
}

pid = PID(**pid_kwargs)

t_params = {
    "start": 0,
    "end": 1000,
    "points": 2000
}
t = np.linspace(t_params["start"], t_params["end"], t_params["points"])
# pid_kwargs["dt"] = (t_params["end"] - t_params["start"]) / t_params["points"]
# print(f"{pid_kwargs["dt"]=}")

setpoint = np.sin(np.deg2rad(t)) * 10000

process_variable = np.zeros_like(t)
pid_sum = np.zeros_like(t)
ff = t * setpoint

for i in range(len(t)):
    pid_sum[i] = pid.update(setpoint[i], process_variable[i], ff[i])


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
    0.02, # >1 for RHS
    0.02, 
    # f"{pid_kwargs=}",
    "\n".join(f"{k}: {v}" for k, v in pid_kwargs.items()),
    transform=plt.gca().transAxes,
    ha="left",
    va="bottom",
    bbox=dict(boxstyle="round", facecolor="white", alpha=0.8)
)
plt.xlabel("Arbitrary Time Units")
plt.ylabel("Arbitrary Position Units")
plt.title("PID demo")
plt.show()