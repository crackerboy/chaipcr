#ifndef _OPTICS_H_
#define _OPTICS_H_

#include <icontrol.h>

class LEDController;

namespace Poco { class Timer; }

////////////////////////////////////////////////////////////////////////////////
// Class Optics
class Optics : public IControl
{
public:
    Optics(unsigned int lidSensePin, std::shared_ptr<LEDController> ledController, MUX &&photoDiodeMux);
    ~Optics();

    void process();
	
	//accessors
    inline bool lidOpen() const { return _lidOpen; }

    inline bool collectData() const { return _collectData; }
    void setCollectData(bool state);

    inline std::shared_ptr<LEDController> getLedController() { return _ledController; }
    inline MUX& getPhotodiodeMux() { return _photodiodeMux; }

private:
    void collectDataCallback(Poco::Timer &timer);
	
private:
    std::atomic<bool> _lidOpen;

    std::atomic<bool> _collectData;
    Poco::Timer *_collectDataTimer;
    unsigned int _ledNumber;

    GPIO _lidSensePin;
    std::shared_ptr<LEDController> _ledController;
    MUX _photodiodeMux;
};

#endif
