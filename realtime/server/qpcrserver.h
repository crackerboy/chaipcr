#ifndef _QPCRSERVER_H_
#define _QPCRSERVER_H_

#include <Poco/Util/ServerApplication.h>
#include <vector>

using namespace std;

////////////////////////////////////////////////////////////////////////////////
// Class QPCRServer
class QPCRServer: public Poco::Util::ServerApplication {
protected:
	int main(const vector<string> &);
};

#endif
