class TroubleshootingData {
  static Map<String, List<TroubleshootingStep>> steps = {
    'Refrigerator': [
      TroubleshootingStep(
        title: 'Check the power connection',
        description:
            'Make sure the refrigerator is properly plugged in and the outlet is working. Try plugging another appliance to test the outlet.',
      ),
      TroubleshootingStep(
        title: 'Check the temperature settings',
        description:
            'Ensure the temperature dial is not set to "Off". Recommended setting is between 3-5 for the fridge and -18°C for the freezer.',
      ),
      TroubleshootingStep(
        title: 'Check the door seals',
        description:
            'Inspect the rubber door gaskets for cracks or gaps. A damaged seal causes cooling loss. Close a piece of paper in the door — if it slides out easily, the seal needs replacement.',
      ),
      TroubleshootingStep(
        title: 'Clean the condenser coils',
        description:
            'Dusty coils at the back or bottom reduce cooling efficiency. Unplug the unit and clean the coils with a brush or vacuum.',
      ),
      TroubleshootingStep(
        title: 'Check for ice buildup',
        description:
            'Excessive frost in the freezer may block airflow. Defrost the unit manually by turning it off for 24 hours with the doors open.',
      ),
    ],
    'Air Conditioner': [
      TroubleshootingStep(
        title: 'Check the power and remote',
        description:
            'Ensure the unit is plugged in and the remote has working batteries. Try pressing the power button directly on the unit.',
      ),
      TroubleshootingStep(
        title: 'Clean or replace the air filter',
        description:
            'A dirty filter blocks airflow and reduces cooling. Remove the front panel, take out the filter, wash it with water, dry completely, and reinstall.',
      ),
      TroubleshootingStep(
        title: 'Check the thermostat setting',
        description:
            'Set the temperature to at least 24°C below the current room temperature. Make sure it is set to "Cool" mode, not "Fan" only.',
      ),
      TroubleshootingStep(
        title: 'Check for ice on the evaporator coils',
        description:
            'If the unit blows warm air or weak airflow, ice may have formed on the coils. Turn off the AC and run "Fan" mode for 1-2 hours to defrost.',
      ),
      TroubleshootingStep(
        title: 'Check for refrigerant leak',
        description:
            'If the unit runs but does not cool, the refrigerant may be low. Look for ice on the copper pipes outside. This requires a professional technician.',
      ),
    ],
    'Television': [
      TroubleshootingStep(
        title: 'Check the power connection',
        description:
            'Ensure the TV is plugged in and the power indicator light is on. Try a different outlet or check if the AVR or surge protector is working.',
      ),
      TroubleshootingStep(
        title: 'Check the remote control',
        description:
            'Replace the remote batteries and try again. If it still does not respond, use the buttons directly on the TV.',
      ),
      TroubleshootingStep(
        title: 'Check the input source',
        description:
            'Press the "Source" or "Input" button and select the correct input (HDMI 1, AV, etc.) that matches your connected device.',
      ),
      TroubleshootingStep(
        title: 'Restart the TV',
        description:
            'Unplug the TV from the outlet, wait 60 seconds, then plug it back in. This clears temporary software glitches.',
      ),
      TroubleshootingStep(
        title: 'Check for picture but no sound',
        description:
            'Increase the volume and check if the TV is muted. If using external speakers, check the audio cable connections.',
      ),
    ],
    'Washing Machine': [
      TroubleshootingStep(
        title: 'Check the power and water supply',
        description:
            'Ensure the machine is plugged in and the water inlet valve is fully open. Check if the water hose is kinked or blocked.',
      ),
      TroubleshootingStep(
        title: 'Check the door/lid lock',
        description:
            'The machine will not start if the door is not fully closed and latched. Open and firmly close the door, then try again.',
      ),
      TroubleshootingStep(
        title: 'Check for error codes',
        description:
            'Look at the display panel for any error code (e.g., E1, F2). Refer to the manual or search the model number + error code online.',
      ),
      TroubleshootingStep(
        title: 'Check if the machine is overloaded',
        description:
            'Too many clothes can cause the machine to stop mid-cycle. Remove some items and try again. Maximum load is usually 80% of the drum.',
      ),
      TroubleshootingStep(
        title: 'Clean the drain filter',
        description:
            'A clogged drain filter prevents the machine from draining. Locate the filter (usually at the front bottom), unscrew it, clean out lint and debris.',
      ),
    ],
    'Microwave': [
      TroubleshootingStep(
        title: 'Check the power connection',
        description:
            'Ensure the microwave is properly plugged in. Check if the circuit breaker for that outlet has tripped.',
      ),
      TroubleshootingStep(
        title: 'Check the door switches',
        description:
            'The microwave will not operate if the door is not completely closed. Open and firmly close the door. Check for any visible damage to the door latch.',
      ),
      TroubleshootingStep(
        title: 'Check the turntable',
        description:
            'Ensure the glass turntable and its support ring are correctly positioned. A misaligned turntable can stop the microwave from running.',
      ),
      TroubleshootingStep(
        title: 'Reset the microwave',
        description:
            'Unplug the microwave for 2 minutes, then plug it back in. This resets the internal computer and may clear the issue.',
      ),
    ],
    'Electric Fan': [
      TroubleshootingStep(
        title: 'Check the power connection',
        description:
            'Ensure the fan is plugged in properly. Test the outlet with another device to confirm it has power.',
      ),
      TroubleshootingStep(
        title: 'Check the speed control',
        description:
            'Try all speed settings. If one speed works but others do not, the capacitor or speed switch may be faulty.',
      ),
      TroubleshootingStep(
        title: 'Clean the fan blades and motor',
        description:
            'Dust buildup can slow down or stop the motor. Unplug the fan, disassemble the blade guard, and wipe all blades and the motor vent.',
      ),
      TroubleshootingStep(
        title: 'Check for blade obstruction',
        description:
            'Spin the blades manually (when unplugged). If they do not spin freely, something may be caught in the motor or the bearing may be worn.',
      ),
    ],
    'Water Dispenser': [
      TroubleshootingStep(
        title: 'Check the power connection',
        description:
            'Ensure the dispenser is plugged in and the power switch is turned on. Check if the thermostat or safety fuse has tripped.',
      ),
      TroubleshootingStep(
        title: 'Check the water bottle',
        description:
            'Ensure the water bottle is properly seated on the dispenser. A loose bottle causes air gaps that stop water flow.',
      ),
      TroubleshootingStep(
        title: 'Check for leaks',
        description:
            'Inspect the drip tray and the area around the bottle connection. If water is leaking, the bottle may be cracked or the seal is damaged.',
      ),
      TroubleshootingStep(
        title: 'Descale the unit',
        description:
            'Mineral buildup from hard water can block water flow. Run a descaling solution (water + white vinegar) through the system every 3 months.',
      ),
    ],
    'Others': [
      TroubleshootingStep(
        title: 'Check the power connection',
        description:
            'Ensure the appliance is properly plugged in and the outlet has power. Try a different outlet if available.',
      ),
      TroubleshootingStep(
        title: 'Check for visible damage',
        description:
            'Inspect the power cord, plug, and body of the appliance for any cracks, burns, or frayed wires. Do not use if there is visible damage.',
      ),
      TroubleshootingStep(
        title: 'Restart the appliance',
        description:
            'Turn off and unplug the appliance for 2-3 minutes, then plug it back in and try again. This resets internal components.',
      ),
      TroubleshootingStep(
        title: 'Check the user manual',
        description:
            'Refer to the troubleshooting section of your appliance\'s user manual for model-specific guidance.',
      ),
    ],
  };
}

class TroubleshootingStep {
  final String title;
  final String description;

  TroubleshootingStep({
    required this.title,
    required this.description,
  });
}