# Edge Detection Chip

2020_spring IC Design Lab final project, NTUEE

## Introduction
We implemented the edge part of **Dade Toonify**<sup>[1](#Reference)</sup> in verilog.

CHIP/CHIP.v is the top module, and all sub-modules bave there own directories. In Testbench/pattern, contains all test patterns for each step, which are generated with Testbench/bitwise_full.py.

We load in 20*20 pixels of gray scale image per tile. The output is 1 or 0, indicating a edge or not.

## Steps and Description
### [Median Filter](https://en.wikipedia.org/wiki/Median_filter)
Change the current pixel to the median of its adjacent pixels.
### [Gaussian Filter](https://en.wikipedia.org/wiki/Gaussian_filter)
Current pixel become the result of convolution with a 5*5 gaussian filter.
### [Sobel Gradient Calculation](https://en.wikipedia.org/wiki/Sobel_operator)
Find the magnitude and the direction of gradient of the current pixel.
### [Non-Maximum Supression](https://en.wikipedia.org/wiki/Canny_edge_detector)
After previous steps, the edge becomes blur, non-maximum suppression can make the edge thinner.
### [Hysteresis](https://en.wikipedia.org/wiki/Canny_edge_detector)
Double threshold and Hysteresis combined, link the edges into a continuous line, and delete isolated small edges.

## Entire Block Diagram

## Sub-modules
### Median Filter
### Gaussian Filter
### Sobel Gradient Calculation
### Non-Maximum Supression
### Hysteresis

## Usage
```bash
ncverilog +access+r -f files.f
```
## Reference
1. [Kevin Dade, "Toonify: Cartoon Photo Effect Application"](https://stacks.stanford.edu/file/druid:yt916dh6570/Dade_Toonify.pdf?fbclid=IwAR1gOlnXmNU__UuYD7Nf0CCpfYra8a3TEcoqNKSrLZkzdsH3rN_HOahgmfU)
2. [FienSoP/canny_edge_detector](https://github.com/FienSoP/canny_edge_detector)