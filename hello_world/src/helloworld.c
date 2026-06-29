#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "xil_cache.h"
#include "xil_mmu.h"

#define BRAM_BASE 0x40000000U
#define GPIO_BASE 0x41200000U

int main()
{
    u32 v;

    init_platform();

    print("\r\nBRAM TEST VERSION 02\r\n");

    Xil_DCacheDisable();
    Xil_ICacheDisable();

    Xil_SetTlbAttributes(BRAM_BASE, 0x14de2U);
    Xil_SetTlbAttributes(GPIO_BASE, 0x14de2U);

    xil_printf("BRAM_BASE = 0x%08x\r\n", BRAM_BASE);

    print("before BRAM write\r\n");
    Xil_Out32(BRAM_BASE + 0x00, 0x12345678U);
    print("after BRAM write\r\n");

    print("before BRAM read\r\n");
    v = Xil_In32(BRAM_BASE + 0x00);
    print("after BRAM read\r\n");

    xil_printf("BRAM[0] = 0x%08x\r\n", v);

    print("before GPIO read\r\n");
    v = Xil_In32(GPIO_BASE + 0x00);
    print("after GPIO read\r\n");

    xil_printf("GPIO[0] = 0x%08x\r\n", v);

    print("BRAM/GPIO test done\r\n");

    while (1) {
    }

    cleanup_platform();
    return 0;
}