all: start

start:
	argos3 -c rumba.argos

test_components:
	argos3 -c ./test/test.argos