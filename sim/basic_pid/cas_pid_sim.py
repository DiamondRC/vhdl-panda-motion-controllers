import time

class PID:
    def __init__(self, kp, ki, kd, setpoint=0, output_limits=(None, None)):
        self.kp = kp
        self.ki = ki
        self.kd = kd
        self.setpoint = setpoint
        self._min_output, self._max_output = output_limits
        
        self._integral = 0
        self._last_error = 0
        self._last_time = time.time()

    def update(self, measurement):
        now = time.time()
        dt = now - self._last_time
        if dt <= 0: return 0
        
        error = self.setpoint - measurement
        
        # Proportional
        p = self.kp * error
        
        # Integral with basic anti-windup
        self._integral += error * dt
        i = self.ki * self._integral
        
        # Derivative
        d = self.kd * (error - self._last_error) / dt
        
        output = p + i + d
        
        # Apply output limits
        if self._min_output is not None:
            output = max(self._min_output, output)
        if self._max_output is not None:
            output = min(self._max_output, output)
            
        self._last_error = error
        self._last_time = now
        return output

class CascadedController:
    def __init__(self):
        # Outer Loop: Position (Inputs: Position, Outputs: Target Velocity)
        # Low Ki/Kd usually works best here to avoid oscillation
        self.pos_pid = PID(kp=2.0, ki=0.1, kd=0.01, output_limits=(-100, 100))
        
        # Inner Loop: Velocity (Inputs: Velocity, Outputs: Control Signal/PWM)
        # Needs to be tuned to be snappy
        self.vel_pid = PID(kp=1.5, ki=0.5, kd=0.05, output_limits=(-255, 255))

    def calculate(self, target_pos, current_pos, current_vel):
        # 1. Update outer loop setpoint
        self.pos_pid.setpoint = target_pos
        
        # 2. Get required velocity from position error
        target_velocity = self.pos_pid.update(current_pos)
        
        # 3. Update inner loop setpoint with the result from outer loop
        self.vel_pid.setpoint = target_velocity
        
        # 4. Get final control signal (e.g., motor voltage)
        control_signal = self.vel_pid.update(current_vel)
        
        return control_signal, target_velocity

# --- Example Usage ---
controller = CascadedController()

# Simulated system variables
current_pos = 0.0
current_vel = 0.0
target_pos = 50.0

print(f"{'Time':>5} | {'Pos':>6} | {'Vel':>6} | {'Output':>8}")
for i in range(20):
    # Calculate control signal
    output, target_v = controller.calculate(target_pos, current_pos, current_vel)
    
    # Simulate simple physics (Euler integration)
    # In a real scenario, these come from your encoders/sensors
    current_vel += (output * 0.01)  # Output affects acceleration
    current_pos += (current_vel * 0.1) # Velocity affects position
    
    print(f"{i*0.1:5.1f} | {current_pos:6.2f} | {current_vel:6.2f} | {output:8.2f}")
    time.sleep(0.1)