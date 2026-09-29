class TroubleshootingData {
  static Map<String, List<TroubleshootingStep>> steps = {
    'Refrigerator': [
      TroubleshootingStep(
        title: 'Check the Power Connection',
        description:
            'Make sure the refrigerator is properly plugged in and the outlet is working. Try plugging another device into the same outlet to confirm it has power.',
      ),
      TroubleshootingStep(
        title: 'Check the Temperature Setting',
        description:
            'Look at the thermostat or temperature dial inside the fridge. Make sure it is not accidentally set to "Off" or to the lowest cooling level.',
      ),
      TroubleshootingStep(
        title: 'Check the Door Seal',
        description:
            'Make sure the door closes all the way and nothing (like food or containers) is blocking it from sealing properly. A door that doesn\'t close fully can stop the fridge from cooling.',
      ),
      TroubleshootingStep(
        title: 'Listen for the Compressor',
        description:
            'Place your hand or ear near the back/bottom of the fridge and listen for a faint humming sound. This means the compressor is running. If you hear nothing at all, note this down for the technician.',
      ),
      TroubleshootingStep(
        title: 'Check the Back and Bottom Vents',
        description:
            'Make sure the vents at the back or bottom of the fridge are not blocked by dust, boxes, or being pushed too close to the wall. Blocked vents can affect cooling.',
      ),
    ],
    'Air Conditioner': [
      TroubleshootingStep(
        title: 'Check Power and Remote',
        description:
            'Confirm the unit is properly plugged in, and replace the remote batteries if the remote is not responding.',
      ),
      TroubleshootingStep(
        title: 'Check the Circuit Breaker',
        description:
            'Check your breaker box to see if the breaker connected to the aircon has tripped. If it has, switch it back on and see if the unit turns on.',
      ),
      TroubleshootingStep(
        title: 'Check for Blinking Error Lights',
        description:
            'Look at the indoor unit for any blinking lights. If you see one blinking, try to count how many times it blinks in a row and write it down — this code helps the technician identify the issue faster.',
      ),
      TroubleshootingStep(
        title: 'Check the Air Filter',
        description:
            'Open the front cover of the indoor unit and check if the air filter looks dusty or dirty. A clogged filter can reduce cooling and cause the unit to run poorly.',
      ),
      TroubleshootingStep(
        title: 'Check the Outdoor Unit',
        description:
            'Make sure the outdoor unit is not blocked by leaves, dust, plants, or objects, and that its fan can spin freely without obstruction.',
      ),
    ],
    'Television': [
      TroubleshootingStep(
        title: 'Check the Power Cable',
        description:
            'Make sure the power cable is firmly plugged into both the TV and the outlet, and that the outlet is working.',
      ),
      TroubleshootingStep(
        title: 'Try a Different Input or Channel',
        description:
            'Switch to a different input source (HDMI, TV tuner) or channel to check if the issue only happens on one source.',
      ),
      TroubleshootingStep(
        title: 'Check the Remote Batteries',
        description:
            'Replace the batteries in the remote and try turning the TV on again, in case the remote itself is the issue.',
      ),
      TroubleshootingStep(
        title: 'Check for Sound Without Picture',
        description:
            'Turn the TV on and listen closely. If you can hear sound but the screen stays completely black, note this down — it helps narrow down the problem.',
      ),
      TroubleshootingStep(
        title: 'Check for a Faint/Dim Image',
        description:
            'In a dark room, turn the TV on and look closely at the screen. If you can barely see a very dim image, this may point to a backlight issue rather than a total TV failure.',
      ),
    ],
    'Washing Machine': [
      TroubleshootingStep(
        title: 'Check Power and Water Supply',
        description:
            'Make sure the machine is plugged in and the water faucet/valve supplying it is fully turned on.',
      ),
      TroubleshootingStep(
        title: 'Check the Load Size',
        description:
            'Avoid overloading the machine. Too many clothes or an unevenly distributed load can prevent the machine from spinning properly.',
      ),
      TroubleshootingStep(
        title: 'Check the Lid or Door',
        description:
            'Make sure the lid (top-load) or door (front-load) is fully closed. Most washing machines will not start or spin if it isn\'t securely shut.',
      ),
      TroubleshootingStep(
        title: 'Check the Drain Hose',
        description:
            'Look at the drain hose for any kinks, bends, or blockage that could be stopping water from draining properly.',
      ),
      TroubleshootingStep(
        title: 'Observe the Spin Cycle',
        description:
            'Run a spin cycle and note if the drum spins weakly, doesn\'t spin at all, or makes unusual noise. Write down what you observe for the technician.',
      ),
    ],
    'Microwave': [
      TroubleshootingStep(
        title: 'Check the Power Connection',
        description:
            'Make sure the microwave is plugged into a working outlet. Try another device on the same outlet to confirm it has power.',
      ),
      TroubleshootingStep(
        title: 'Check the Door Latch',
        description:
            'Make sure the door closes and latches fully. Most microwaves will not turn on at all if the door isn\'t securely shut.',
      ),
      TroubleshootingStep(
        title: 'Check the Timer and Settings',
        description:
            'Confirm you\'ve set a cook time and pressed Start. Some microwaves won\'t run if the time is set to zero.',
      ),
      TroubleshootingStep(
        title: 'Check the Circuit Breaker',
        description:
            'Check your breaker box to see if the breaker or fuse connected to the microwave has tripped, and reset it if needed.',
      ),
    ],
    'Electric Fan': [
      TroubleshootingStep(
        title: 'Check the Power Connection',
        description:
            'Make sure the fan is plugged in and the outlet is working. Try a different outlet if available.',
      ),
      TroubleshootingStep(
        title: 'Check the Speed Switch',
        description:
            'Try switching between all available speed settings to see if any of them work.',
      ),
      TroubleshootingStep(
        title: 'Check for Obstruction',
        description:
            'Make sure nothing is blocking the blades and that they can turn freely by hand when unplugged.',
      ),
      TroubleshootingStep(
        title: 'Check for Unusual Heat or Smell',
        description:
            'Feel if the motor area is unusually hot or if there\'s a burnt smell. If so, stop using the fan immediately and mention this to the technician — do not continue using it.',
      ),
    ],
    'Water Dispenser': [
      TroubleshootingStep(
        title: 'Check the Power Connection',
        description:
            'For hot and cold dispensers, make sure it is plugged in and the power switch (usually at the back) is turned on.',
      ),
      TroubleshootingStep(
        title: 'Check the Water Bottle or Source',
        description:
            'Make sure the water bottle is properly seated and not empty, or that the water line has water flowing into it.',
      ),
      TroubleshootingStep(
        title: 'Test Both Taps',
        description:
            'Try both the hot and cold taps separately to check if only one side isn\'t working, or if both are affected.',
      ),
      TroubleshootingStep(
        title: 'Check for Leaks',
        description:
            'Look underneath and around the base of the dispenser for any signs of water leaking or pooling.',
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