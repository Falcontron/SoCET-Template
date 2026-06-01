#include "pal.h"

int main() {
    PWMRegBlk *pwm = (PWMRegBlk *) PWM_BASE;
    IOMuxRegBlk *iomux = (IOMuxRegBlk *) IO_MUX_BASE;

    iomux->fsel0 = IOM_F0_PWM0_0 | IOM_F0_PWM0_1;


    pwm->per0 = 0x10;
    pwm->duty0 = 0x9; // 50% duty cycle (PWM duty off by 1)

    pwm->per1 = 0x20;
    pwm->duty1 = 0x2; // 1/32 duty cycle

    
    pwm->ctrl0 = 0x5; // center-aligned, active high, enabled
    pwm->ctrl1 = 0x3; // left-aligned, active low, enabled

    return 0;
}
