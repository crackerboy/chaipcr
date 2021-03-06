//
// Chai PCR - Software platform for Open qPCR and Chai's Real-Time PCR instruments.
// For more information visit http://www.chaibio.com
//
// Copyright 2016 Chai Biotechnologies Inc. <info@chaibio.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#include "updatehandler.h"
#include "qpcrapplication.h"
#include "updatemanager.h"

UpdateHandler::UpdateHandler(OperationType type)
{
    _type = type;
}

void UpdateHandler::processData(const boost::property_tree::ptree &requestPt, boost::property_tree::ptree &responsePt)
{
    std::shared_ptr<UpdateManager> updateManager = qpcrApp.updateManager();

    switch (_type)
    {
    case CheckUpdate:
        if (updateManager->checkUpdate())
        {
            switch (updateManager->updateState())
            {
            case UpdateManager::Unavailable:
                responsePt.put("device.update_available", "unavailable");
                break;

            case UpdateManager::Available:
                responsePt.put("device.update_available", "available");
                break;

            case UpdateManager::Downloading:
            case UpdateManager::ManualDownloading:
                responsePt.put("device.update_available", "downloading");
                break;

            case UpdateManager::Updating:
                responsePt.put("device.update_available", "updating");
                break;

            default:
                responsePt.put("device.update_available", "unknown");

                UpdateManager::ErrorInfo error = qpcrApp.updateManager()->lastError();

                if (error.code != UpdateManager::ErrorInfo::NoError)
                {
                    switch (error.code)
                    {
                    case UpdateManager::ErrorInfo::InvalidImage:
                        responsePt.put("device.update_error.code", "invalid_image");
                        break;

                    case UpdateManager::ErrorInfo::UplodFaild:
                        responsePt.put("device.update_error.code", "upload_failed");
                        break;

                    case UpdateManager::ErrorInfo::NetworkError:
                        responsePt.put("device.update_error.code", "network_error");
                        break;

                    default:
                        responsePt.put("device.update_error.code", "unknown_error");
                        break;
                    }

                    responsePt.put("device.update_error.message", error.message);
                }

                break;
            }
        }
        else
        {
            setStatus(Poco::Net::HTTPResponse::HTTP_GATEWAY_TIMEOUT);
            setErrorString("Timeout");

            JsonHandler::processData(requestPt, responsePt);
        }

        break;

    case Update:
    {
        try
        {
            if (!updateManager->update())
            {
                setStatus(Poco::Net::HTTPResponse::HTTP_PRECONDITION_FAILED);
                setErrorString("Update is not available");

                JsonHandler::processData(requestPt, responsePt);
            }
        }
        catch (const UpdateManager::UpdateException &ex)
        {
            setStatus(Poco::Net::HTTPResponse::HTTP_PRECONDITION_FAILED);

            switch (ex.error.code)
            {
            case UpdateManager::ErrorInfo::InvalidImage:
                responsePt.put("device.update_error.code", "invalid_image");
                break;

            case UpdateManager::ErrorInfo::UplodFaild:
                responsePt.put("device.update_error.code", "upload_failed");
                break;

            case UpdateManager::ErrorInfo::NetworkError:
                responsePt.put("device.update_error.code", "network_error");
                break;

            default:
                responsePt.put("device.update_error.code", "unknown_error");
                break;
            }

            responsePt.put("device.update_error.message", ex.error.message);
        }
        catch (const std::exception &ex)
        {
            setStatus(Poco::Net::HTTPResponse::HTTP_PRECONDITION_FAILED);
            setErrorString(ex.what());

            JsonHandler::processData(requestPt, responsePt);
        }

        break;
    }

    default:
        setStatus(Poco::Net::HTTPResponse::HTTP_BAD_REQUEST);
        setErrorString("Unknown opeation type");

        JsonHandler::processData(requestPt, responsePt);

        break;
    }
}
