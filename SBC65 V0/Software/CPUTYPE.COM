�T� 	����i��
�w� 	�L ���� 	�L �

SBC-65 CPU TYPE TESTER V1.00
 
**** CPU is NMOS - 6502 ****
 
**** CPU is CMOS - 65C02 ****
 OPLEN
	JSR PUTOPC
	JSR I2CDP                             $000D  ALF                              $000A  
EOT       