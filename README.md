# mazecaster_fpga
This is our final project for 6.205 (Digital Systems Laboratory) Fall 2024 at MIT.

## Table of Contents
- [Description](#description)
- [Introduction](#introduction)
- [Controls & Ray Calculation](#controls&raycalculation)
- [Ray Processing](#rayprocessing)
- [Frame Processing](#frameprocessing)
- [Liscence](#liscence)

## Description
This project developed a pseudo-3D world renderer by ray-casting on an FPGA to simulate a first-person view within a 2D grid-based environment.

## Introduction
Ray-casting calculates intersections between the player's viewpoint and walls to render a 3D perspective, inspired by early 3D game engines. Leveraging FPGA hardware enables parallel processing of multiple rays, significantly accelerating rendering, increasing potential frame rates, and reducing latency compared to software implementations.




