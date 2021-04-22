all: start

start:
	argos3 -c rumba.argos

test_components:
	argos3 -c ./test/test.argos

list_sensors:
	argos3 -q sensors

list_actuators:
	argos3 -q actuators