#ifndef __IOPROXYFRAMEBUFFER_H__
#define __IOPROXYFRAMEBUFFER_H__

#include <IOKit/graphics/IOFramebuffer.h>
#include <IOKit/IOBufferMemoryDescriptor.h>


// if this is an IOFramebuffer instead of an IOService, free fails and
// we can't unload. why is that?
class com_doequalsglory_driver_IOProxyFramebuffer : public IOFramebuffer {
	OSDeclareDefaultStructors(com_doequalsglory_driver_IOProxyFramebuffer)
	
public:
	// generic kext setup & teardown
	//virtual bool com_doequalsglory_driver_IOProxyFramebuffer::init(OSDictionary *properties = 0);
	//virtual bool com_doequalsglory_driver_IOProxyFramebuffer::attach(IOService *provider);
	//virtual IOService *com_doequalsglory_driver_IOProxyFramebuffer::probe(IOService *provider, SInt32 *score);
	//virtual void com_doequalsglory_driver_IOProxyFramebuffer::detach(IOService *provider);
	//virtual void com_doequalsglory_driver_IOProxyFramebuffer::free();
	
	virtual bool start(IOService *provider);
	virtual void stop(IOService *provider);
	
	//virtual bool com_doequalsglory_driver_IOProxyFramebuffer::requestTerminate( IOService * provider, IOOptionBits options );
	
	//virtual IOReturn com_doequalsglory_driver_IOProxyFramebuffer::open(void);
	// close is not being called
	//virtual void com_doequalsglory_driver_IOProxyFramebuffer::close(void);
	
	//
	// IOFramebuffer specific methods
	//
	
	// perform first-time setup of the framebuffer
	virtual IOReturn enableController(void);
	
	// memory management
	virtual UInt32				getApertureSize(IODisplayModeID, IOIndex);
	virtual IODeviceMemory *	getApertureRange(IOPixelAperture);
	virtual IODeviceMemory *	getVRAMRange(void);
	
	// framebuffer info
	virtual const char *		getPixelFormats();
	virtual IOReturn			getInformationForDisplayMode(IODisplayModeID, IODisplayModeInformation *);
	virtual UInt64				getPixelFormatsForDisplayMode(IODisplayModeID, IOIndex);
	virtual IOReturn			getPixelInformation(IODisplayModeID, IOIndex, IOPixelAperture, IOPixelInformation *);
	
	virtual bool				isConsoleDevice(void);
	
	virtual IOReturn			getTimingInfoForDisplayMode(IODisplayModeID, IOTimingInformation *);
	
	virtual IOReturn			getAttribute(IOSelect, UInt32 *);
	virtual IOReturn			setAttribute(IOSelect, UInt32);
	
	// connection info
	virtual IOItemCount			getConnectionCount(void);
	
	virtual IOReturn			getAttributeForConnection(IOIndex, IOSelect, UInt32 *);
	virtual IOReturn			setAttributeForConnection(IOIndex, IOSelect, UInt32);
	
	virtual bool				hasDDCConnect(IOIndex);
	virtual IOReturn			getDDCBlock(IOIndex, UInt32, IOSelect, IOOptionBits, UInt8 *, IOByteCount *);
	
	// display mode accessors
	virtual IOItemCount			getDisplayModeCount();
	virtual IOReturn			getDisplayModes(IODisplayModeID *);
	
	virtual IOReturn			setDisplayMode(IODisplayModeID, IOIndex);
	virtual IOReturn			getCurrentDisplayMode(IODisplayModeID *, IOIndex *);
	
	virtual IOReturn			setStartupDisplayMode(IODisplayModeID, IOIndex);
    virtual IOReturn			getStartupDisplayMode(IODisplayModeID *, IOIndex *);
	
private:
	IOBufferMemoryDescriptor *	fBuffer;
	
	IODisplayModeID				fCurrentDisplayMode;
	IOIndex						fCurrentDepth;
	
	UInt32						fPowerState;
};

#endif