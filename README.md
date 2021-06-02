# [IRS] robotici_rumba

Project for the course of Unibo Intelligent Robotic Systems 2019-2020.

This project aims to develop a subsumption architecture for a robot that has a similar behaviour to the one of a rumba robot.

The robot has to:
- explore the room where the robot is deployed
- clean the room
- return to base if the room temperature is over some hard-coded value (currently 30°C)
- return to base if with low battery values in order to recharge it

The project uses:
- [Argos 3](https://github.com/ilpincy/argos3) for the simulation environment
- [Luagraph library](https://github.com/chen0040/lua-graph)
- Custom implementation of [A* library developed by another user](https://github.com/lattejed/a-star-lua)

The project is fully written in Lua language.

## Algorithms used
- A*
- [Yen's algorithm](https://en.wikipedia.org/wiki/Yen%27s_algorithm)
- Subsumption architecture

## How to run
- Download the repo
- Place yourself in the main directory
- ```make```
