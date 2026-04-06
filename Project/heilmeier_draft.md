1. What are you trying to do?

I want to design a small hardware accelerator for one part of a neural network. My chiplet will speed up the dense layer operation by doing the multiply and add calculations in hardware instead of only in software. The goal is to make it correct, eligable for synthesis, and faster than the software version.

2. How is it done today, and what are the limits?

Today, dense layers are usually run in software on a CPU or GPU using tools such as NumPy or PyTorch. This method works, however, it can be slower and less efficient for repeated small calculations.

3. What is new in your approach and why will it work?

My approach is to build custom hardware for only the main kernel instead of the whole model. I will focus on one dense layer matrix vector multiply using INT8 data. This should work well because the operation is simple, common in AI and ML, easy to test the performance, and matches the  scope of my project.
