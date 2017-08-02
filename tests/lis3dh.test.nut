// MIT License
//
// Copyright (c) 2015-17 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

@include "github:electricimp/LIS3DH/LIS3DH.device.lib.nut@develop"

class MyTestCase extends ImpTestCase {
	
    _i2c = hardware.i2c89;
    _intPin = hardware.pin1;

	function getLIS() {
		_i2c.configure(CLOCK_SPEED_400_KHZ);
		local accel = LIS3DH(_i2c, 0x32);
		accel.reset();
		accel.setDataRate(100);
		return accel;
	}

	function testSetReadRegs() {
		local myVal = 0x7f; // random value to go into a register
		local accel = getLIS();
		accel._setReg(LIS3DH_CTRL_REG3, myVal);
		this.assertEqual(myVal, accel._getReg(LIS3DH_CTRL_REG3));
	}

	function testAccel() {
		local accel = getLIS();
		local reading = accel.getAccel();
		this.assertBetween(reading.z, 0.9, 1.1); // for this test, the accelerometer should be sitting still facing up
	}

	function testADC() {
		local accel = getLIS();
		accel.enableADC(true);
		this.assertBetween(accel.readADC(LIS3DH_ADC1), 1.15, 1.25); // for this test, line 1 of the accelerometer ADC should be fed 1.2V
	}

	function testInterruptLatching() {
		local accel = getLIS();
		accel.configureInterruptLatching(true);
		accel.configureClickInterrupt(true);
		accel.configureInertialInterrupt(true);

		imp.sleep(1); // hopefully something gets asserted in this time

		this.assertTrue(accel.getInterruptTable() != 0);
	}

    function testConstruction() {
        local accel = LIS3DH(_i2c, 0x32);
        this.assertTrue(accel._addr == 0x32);
    }

    // test that calling reset correctly resets registers (in particular, 
    // data ready interrupt and range)
    function testInit() {
        local accel = LIS3DH(_i2c, 0x32);
        accel.reset();
        accel.setDataRate(1);
        accel.setRange(4);
        accel.configureDataReadyInterrupt(true);
        local val = false;
        _intPin.configure(DIGITAL_IN, function() {
            val = _intPin.read();
            }.bindenv(this));
        return Promise(function(resolve, reject) {
            accel.reset();
            val = false; // if reset does not reset interrupt and range, then intPin
            // will be asserted and therefore val will become true bfeore
            // the wakeup callback
            imp.wakeup(2, function() {
                if (val || (accel.getRange() != 2)) {
                    reject("did not reset data ready interrupt");
                } else {
                    resolve("rejected data ready interrupt via reset");
                }
            }.bindenv(this));
        }.bindenv(this));
    }

    function testDeviceId() {
        local accel = LIS3DH(_i2c, 0x32);
        this.assertTrue(accel.getDeviceId() == 51);
    }

    function testSetDataRate() {
        local accel = LIS3DH(_i2c, 0x32);
        local r0 = accel.setDataRate(0);
        local r1 = accel.setDataRate(1);
        local r2 = accel.setDataRate(10);
        this.assertTrue((r0 == 0) && (r1 == 1) && (r2 == 10));
    }

    function testGetAccelSync() {
        local accel = getLIS();
        local res = accel.getAccel();
        this.assertTrue(("x" in res ? typeof res.x == "float" : false) &&
            ("y" in res ? typeof res.y == "float" : false) && 
            ("z" in res ? typeof res.z == "float" : false));
    }

    function testGetAccelAsync() {
        return Promise(function(resolve, reject) {
            local accel = getLIS();
            accel.getAccel(function(res) {
                if (("x" in res ? typeof res.x == "float" : false) &&
            ("y" in res ? typeof res.y == "float" : false) && 
            ("z" in res ? typeof res.z == "float" : false)) {
                    resolve("async resolved successfully");
                } else {
                    reject("async did not resolve succesfully");
                }
            }.bindenv(this));
        }.bindenv(this));
    }

    function testEnable() {
        return Promise(function(resolve, reject) {
            local accel = getLIS();
            accel.enable(false);
            imp.wakeup(1, function() {
                local res = accel.getAccel();
                if (res.x || res.y || res.z) {
                    reject("failed to disable axes");
                } else {
                	accel.enable(true);
                    imp.wakeup(1, function() {
                        res = accel.getAccel();
                        // technically it's possible to have all axes at 0 
                        // acceleration but it's unlikedly
                        if (!(res.x || res.y || res.z)) {
                            reject("failed to enable axes");
                        } else {
                            resolve("successfully disabled and enabled axes");
                        }
                    }.bindenv(this));
                }   
            }.bindenv(this));
        }.bindenv(this))
    }

    function testX() {
    	this.info("move the device around in the x direction for this test");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.enable(true);
    		accel.setDataRate(100);
    		imp.wakeup(5, function() {
    			reject("no x readings detected");
    		}.bindenv(this));
    		for(local i = 0; i < 100; ++i) {
    			imp.wakeup(5.0*i/100, function() {
    				if(math.abs(accel.getAccel().x) > 0.1) {
    					resolve("x reading detected");
    				}
    			}.bindenv(this));
    		}
    	}.bindenv(this));
    }

    function testY() {
    	this.info("move the device around in the y direction for this test");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.enable(true);
    		accel.setDataRate(100);
    		imp.wakeup(5, function() {
    			reject("no y readings detected");
    		}.bindenv(this));
    		for(local i = 0; i < 100; ++i) {
    			imp.wakeup(5.0*i/100, function() {
    				if(math.abs(accel.getAccel().y) > 0.1) {
    					resolve("y reading detected");
    				}
    			}.bindenv(this));
    		}
    	}.bindenv(this));
    }

    function testZ() {
    	this.info("move the device around in the z direction for this test");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.enable(true);
    		accel.setDataRate(100);
    		imp.wakeup(5, function() {
    			reject("no z readings detected");
    		}.bindenv(this));
    		for(local i = 0; i < 100; ++i) {
    			imp.wakeup(5.0*i/100, function() {
    				if(math.abs(accel.getAccel().z) > 0.1) {
    					resolve("z reading detected");
    				}
    			}.bindenv(this));
    		}
    	}.bindenv(this));
    }

    function testXHighInterrupt() {
    	this.info("move the device so that it experiences a positive x acceleration");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.enable(true);
    		accel.setDataRate(100);
    		_intPin.configure(DIGITAL_IN, function() {
    			resolve("interrupt received");
    		}.bindenv(this))
    		imp.wakeup(5, function() {
    			reject("no interrupt detected within 5 seconds");
    		}.bindenv(this));
    		accel.configureInertialInterrupt(true, 1, 5, LIS3DH_X_HIGH);
    	}.bindenv(this));
    }

    function testYHighInterrupt() {
    	this.info("move the device so that it experiences a positive y acceleration");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.enable(true);
    		accel.setDataRate(100);
    		_intPin.configure(DIGITAL_IN, function() {
    			resolve("interrupt received");
    		}.bindenv(this))
    		imp.wakeup(5, function() {
    			reject("no interrupt detected within 5 seconds");
    		}.bindenv(this));
    		accel.configureInertialInterrupt(true, 1, 5, LIS3DH_Y_HIGH);
    	}.bindenv(this));
    }

    function testZHighInterrupt() {
    	this.info("move the device so that it experiences a positive z acceleration");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.enable(true);
    		accel.setDataRate(100);
    		_intPin.configure(DIGITAL_IN, function() {
    			resolve("interrupt received");
    		}.bindenv(this))
    		imp.wakeup(5, function() {
    			reject("no interrupt detected within 5 seconds");
    		}.bindenv(this));
    		accel.configureInertialInterrupt(true, 1, 5, LIS3DH_Z_HIGH);
    	}.bindenv(this));
    }

    function testXLowInterrupt() {
    	this.info("move the device so that it experiences a low x acceleration");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.enable(true);
    		accel.setDataRate(100);
    		_intPin.configure(DIGITAL_IN, function() {
    			resolve("interrupt received");
    		}.bindenv(this))
    		imp.wakeup(5, function() {
    			reject("no interrupt detected within 5 seconds");
    		}.bindenv(this));
    		accel.configureInertialInterrupt(true, 1, 5, LIS3DH_X_LOW);
    	}.bindenv(this));
    }

    function testYLowInterrupt() {
    	this.info("move the device so that it experiences a low y acceleration");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.enable(true);
    		accel.setDataRate(100);
    		_intPin.configure(DIGITAL_IN, function() {
    			resolve("interrupt received");
    		}.bindenv(this))
    		imp.wakeup(5, function() {
    			reject("no interrupt detected within 5 seconds");
    		}.bindenv(this));
    		accel.configureInertialInterrupt(true, 1, 5, LIS3DH_Y_LOW);
    	}.bindenv(this));
    }

    function testZLowInterrupt() {
    	this.info("move the device so that it experiences a low z acceleration");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.enable(true);
    		accel.setDataRate(100);
    		_intPin.configure(DIGITAL_IN, function() {
    			resolve("interrupt received");
    		}.bindenv(this))
    		imp.wakeup(5, function() {
    			reject("no interrupt detected within 5 seconds");
    		}.bindenv(this));
    		accel.configureInertialInterrupt(true, 1, 5, LIS3DH_Z_LOW);
    	}.bindenv(this));
    }

    function testDisableInterrupt() {
    	this.info("try to trigger an interrupt by clicking, shaking, etc.");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.configureInertialInterrupt(true);
    		accel.configureClickInterrupt(true);
    		accel.setDataRate(10);
    		accel.configureDataReadyInterrupt(true);
    		accel.reset(); // this should have disabled interrupts
    		_intPin.configure(DIGITAL_IN, function() {
    			reject("received interrupt when they were disabled");
    		}.bindenv(this));
    		imp.wakeup(5, function() {
    			resolve("no interrupts received after disabling");
    		}.bindenv(this));
    	}.bindenv(this));
    }

    function testSingleClick() {
    	this.info("please tap the accelerometer to test click interrupts");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.configureClickInterrupt(true, LIS3DH_SINGLE_CLICK);
    		_intPin.configure(DIGITAL_IN, function() {
    			if(accel.getInterruptTable().singleClick) {
    				resolve("received single click interrupt");
    			}
    		}.bindenv(this));
    		imp.wakeup(5, function() {
    			reject("did not receive single click within 5 seconds");
    		}.bindenv(this));
    	}.bindenv(this));
    }

    function testDoubleClick() {
    	this.info("please double tap the accelerometer to test double click interrupts");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.configureClickInterrupt(true, LIS3DH_DOUBLE_CLICK);
    		_intPin.configure(DIGITAL_IN, function() {
    			if(accel.getInterruptTable().doubleClick) {
    				resolve("received double click interrupt");
    			}
    		}.bindenv(this));
    		imp.wakeup(5, function() {
    			reject("did not receive double click within 5 seconds");
    		}.bindenv(this));
    	}.bindenv(this));
    }

    function testFreeFallInterrupt() {
    	this.info("please toss the device in the air to test free fall interrupts");
    	return Promise(function(resolve, reject) {
    		local accel = getLIS();
    		accel.configureFreeFallInterrupt(true);
    		_intPin.configure(DIGITAL_IN, function() {
    			resolve("received free fall interrupt");
    		}.bindenv(this));
    		imp.wakeup(8, function() {
    			reject("did not receive free fall interrupt within 8 seconds");
    		}.bindenv(this));
    	}.bindenv(this));
    }

}