/**
 * Maximum device scale
 */
enum adxl362_sensitivity
{
    s_2g = 0x00, // default
    s_4g = 0x40,
    s_8g = 0x80
}

/**
 * Hardware data output rate in Hz
 */
enum adxl362_refresh
{
    r_12_5 = 0x00,
    r_25 = 0x01,
    r_50 = 0x02,
    r_100 = 0x03, // default
    r_200 = 0x04,
    r_400 = 0x05
}

class adxl362
{
    /**
     * Contains the last read values from the accelerometer.
     * Format = {
     *    "x" = 1,
     *    "y" = 2,
     *    "z" = 3
     * }
     */
    _lastRead = null;
    
    /**
     * Internal variables
     */
    _sensitivity = null;
    _refreshRate = null;
    _sampleRate = null;
    _spi = null;
    _cs = null;
    _isRunning = null;
    
    constructor(spi, cs, sensitivity, refreshRate, sampleRate, callback)
    {
        this._spi = spi;
        this._cs = cs;
        this._sensitivity = sensitivity;
        this._refreshRate = refreshRate;
        this._sampleRate = sampleRate;
        this._isRunning = false;
        
        // Configure imp hardware
        spi.configure(CLOCK_IDLE_LOW, 3750); // alter this to change SPI bus speed
        cs.configure(DIGITAL_OUT);
        cs.write(1);
        
        // Soft reset adxl
        writeOneRegister("\x1f", "\x52");
        imp.sleep(0.01); // sleep to make sure write completes
        
        // Configure adxl
        local setting = format("%c", (0x10 | this._sensitivity | this._refreshRate));
        writeOneRegister("\x2c", setting); // set output to +-8g at 100Hz
        writeOneRegister("\x2d", "\x22"); // turn measurement on, ultra low noise
        imp.sleep(0.01);
        
        // Start sampling
        readAcc();
    }
    
    /**
     * Call this with true to start running.
     * If you ever want to stop before the next call.
     */
    function run(trueFalse)
    {
        if (this._isRunning == trueFalse) {
            return;
        } else if (!this._isRunning) {
            this._isRunning = true;
            this.readAcc();
        } else {
            this._isRunning = false;
        }
    }
    
    // Read X/Y/Z
    function readAcc() {
        if (!this._isRunning) {
            return;
        }
        this._cs.write(0);
        
        this._spi.write("\x0b"); // Register mode
        this._spi.write("\x0e"); // start with x
    
        local s = hardware.spi189.readblob(6);
        
        this._cs.write(1);
        
        local x = ((s[1] << 28) + (s[0] << 20)) >> 20;
        local y = ((s[3] << 28) + (s[2] << 20)) >> 20;
        local z = ((s[5] << 28) + (s[4] << 20)) >> 20;
        
        server.log(format("value %i / %i / %i", x, y, z));
        this._lastRead = {
            x = x,
            y = y,
            z = z
        };
        
        // Callback requires closure to retain class context
        imp.wakeup(this._sampleRate, this.readAcc.bindenv(this));
    }
    
    function readOneRegister(regAddress) {
        this._cs.write(0);
        
        this._spi.write("\x0b");
        this._spi.write(regAddress);
        local regValue = this._spi.readblob(1);
        
    	this._cs.write(1);
    	return regValue[0];
    }
    
    function writeOneRegister(regAddress, regValue) {
        this._cs.write(0);
        
        this._spi.write("\x0a");
        this._spi.write(regAddress);
        this._spi.write(regValue);
        
        this._cs.write(1);
    }
}

/**
 * START CUSTOM CODE
 */
 
local newAccel = function () {
    
}

local adxl = adxl362(
    hardware.spi189,
    hardware.pin5,
    adxl362_sensitivity.s_2g,
    adxl362_refresh.r_100,
    0.5,
    newAccel
);
adxl.run(true);
