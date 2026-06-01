# Features to Add

Something you might notice is the weird bit mappings when it comes to the tcr and tccmr registers. This is because the timer was based off the STM32F0 TIM1 advanced timer and tried to match those bit mappings to leave room for additional features, which would fill in the missing bit mappings as they were added.

As it is now, the "advanced" timer is actually quite lacking in a number of features

 - down and up/down counting
 - DMA request generation
 - complementary outputs with programmable dead-time
 - input filter for input signal instability
 - etc.

As features are added, it's very possible that an overhaul of the current design is needed. However, the goal was that the current design lays a solid foundation for the timer to be understood and improved upon in the future.
