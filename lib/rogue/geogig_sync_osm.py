from base64 import b64encode
from optparse import make_option
import json
import urllib
import urllib2
import argparse
import time

def make_request(url, params, auth=None):
    """
    Prepares a request from a url, params, and optionally authentication.
    """
    req = urllib2.Request(url + urllib.urlencode(params))

    if auth:
        req.add_header('AUTHORIZATION', 'Basic ' + auth)

    return urllib2.urlopen(req)

def beginTransaction(verbose, url, auth):
    if verbose > 0:
        print('Starting transaction...')
    params = {'output_format': 'JSON'}
    request = make_request(url=url+'beginTransaction.json?', params=params, auth=auth)

    if request.getcode() != 200:
        raise Exception("action failed: Status Code {0}".format(request.getcode()))

    response = json.loads(request.read())

    if not response['response']['success']:
        raise Exception("An error occurred on action: {0}".format(response['response']['error']))

    if verbose > 0:
        print('Transaction started.')
    transactionId = response['response']['Transaction']['ID']
        
    return transactionId;

def endTransaction(verbose, url, auth, cancel, transactionId):
    if verbose > 0:
        print('Ending transaction...')
    params = {'output_format': 'JSON', 'cancel': cancel, 'transactionId': transactionId}
    request = make_request(url=url+'endTransaction.json?', params=params, auth=auth)

    if request.getcode() != 200:
        raise Exception("EndTransaction failed: Status Code {0}".format(request.getcode()))
    
    response = json.loads(request.read())
    
    if not response['response']['success']:
        raise Exception("An error occurred on endTransaction: {0}".format(response['response']['error']))

    if verbose > 0:
        print('Transaction ended.')

def checkout(verbose, url, auth, branch, transactionId):
    if verbose > 0:
        print "Checking out "+branch+" branch..."
    params = {'output_format': 'JSON', 'branch': branch, 'transactionId':transactionId}
    request = make_request(url=url+'checkout.json?', params=params, auth=auth)

    if request.getcode() != 200:
        raise Exception("Checkout for branch "+branch+" failed: Status Code {0}".format(request.getcode()))
        
    response = json.loads(request.read())
    
    if response['response']['success']:
        newBranch = response['response']['NewTarget']
        if verbose > 0:
            print "Checked out "+newBranch+' branch.'
        return newBranch
    else:
        print "----"
        print "Checkout for "+branch+" branch failed."
        print "Error Message: "+response['response']['error']
        return None

def pollTask(url, auth, taskID):
    params = {}
    request = make_request(url=url+'/'+str(taskID)+'.json', params=params, auth=auth)

    #print request.getcode()
    if request.getcode() != 200:
        raise Exception("Get Task Status Failed: Status Code {0}".format(request.getcode()))
    
    response = json.loads(request.read())

    status = response['task']['status']
    
    progress = None
    try:
        progress = response['task']['progress']
    except:
        progress = None
    
    result = None
    try:
        result = response['task']['result']
    except:
        result = None
        
    errorMessage = None
    try:
        errorMessage = response['task']['error']['message']
    except:
        errorMessage = None
    
    return status, progress, result, errorMessage

def printTaskStatus(taskID, status, progress, result, errorMessage):

    if status == "RUNNING":
        print "----"
        print "++Task "+str(taskID)+" is running."
        if progress:
            progress_task = progress['task']
            if progress_task == 'Committing features...':
                print progress_task
            elif progress_task == 'Importing into GeoGig repo...':
                print progress_task+' '+str(progress['amount'])+' entities imported'
            else:
                print "Current Step: "+str(progress['task'])
                print "Entities Processed: "+str(progress['amount'])
        if result:
            print "Entities Processed: "+str(result['OSMReport']['processedEntities'])
    elif status == "FAILED":
        print "----"
        print "++Task "+str(taskID)+" failed with error message: "+errorMessage+"."
    elif status == "FINISHED":
        print "----"
        print "++Task "+str(taskID)+" is finished."
        if result:
            print "Entities Processed: "+str(result['OSMReport']['processedEntities'])
    elif status == "CANCELLED":
        print "----"
        print response
        print "++Task "+str(taskID)+" was cancelled."
        print "Entities Processed: "+str(result['OSMReport']['processedEntities'])
    else:
        print "----"
        print "++Task "+str(taskID)+" is "+status+"."
 
def cancelTask(url, auth, taskID, printStatus):
    print('Downloading from OpenStreetMap ...')
    params = {}
    request = make_request(url=url+'/'+str(taskID)+'.json?cancel=true', params=params, auth=auth)

    if request.getcode() != 200:
        raise Exception("Could not cancel task: Status Code {0}".format(request.getcode()))
    
    response = json.loads(request.read())

    taskStatus = response['task']['status']
    
    if printStatus:
        if taskStatus == "CANCELLED":
            print "++Task "+str(taskID)+" was cancelled."
        else:
            print "++Error.  Could not cancel task "+str(taskID)+".  Task is "+str(taskStatus)+"."
    
    return taskStatus;

def waitOnTask(verbose, url, auth, taskID, timeout):
    maxTime = timeout
    timeSlept = 0
    sleepCycle = 5
    taskStatus = None
    
    if verbose > 0:
        print "----------------------------------"
    print "Maximum wait time is "+str(maxTime)+" seconds.  Waiting for task "+str(taskID)+"..."
    while timeSlept < maxTime:
        taskStatus, taskProgress, taskResult, errorMessage = pollTask(url, auth, taskID)
        if verbose > 0:
            printTaskStatus(taskID, taskStatus, taskProgress, taskResult, errorMessage)
        if not (taskStatus in ['WAITING','RUNNING']):
            break
        if verbose > 0:
            print "Time: "+str(timeSlept)+"/"+str(maxTime)
        time.sleep(sleepCycle)
        timeSlept += sleepCycle
    
    if taskStatus in ['WAITING','RUNNING']:
        print "Task "+str(taskID)+" timed out after "+str(timeSlept)+" seconds."
        print "Attempting to cancel task "+str(taskID)
        maxTime = 60
        timeSlept = 0
        sleepCycle = 4
        while timeSlept < maxTime:
            taskStatus = cancelTask(url, auth, taskID, True)
            if not (taskStatus in ['WAITING','RUNNING']):
                break
            if verbose > 0:
                print "Time: "+str(timeSlept)+"/"+str(maxTime)
            time.sleep(sleepCycle)
            timeSlept += sleepCycle
    
    if verbose > 0:
        print "Task "+str(taskID)+" is done"

def downloadFromOSM(verbose, url, auth, transactionId, update, mapping, bbox):
    if verbose>0:
        print('Downloading from OpenStreetMap ...')
    params = {'output_format': 'JSON', 'update': update, 'mapping': mapping, 'bbox': bbox, 'transactionId':transactionId}
    request = make_request(url=url+'osm/download.json?', params=params, auth=auth)

    if request.getcode() != 200:
        raise Exception("OSM Download failed: Status Code {0}".format(request.getcode()))
        
    response = json.loads(request.read())
    
    taskID = response['task']['id']
    
    
    if response['task']['status'] == 'FAILED':
        raise Exception("An error occurred when pulling new data from OSM: {0}".format(response['task']['status']))

    if verbose > 0:
        if response['task']['status'] == 'WAITING':
            print('Download from OpenStreetMap is waiting to be processed.  Task ID is '+str(taskID)+'.')
    
    if verbose > 0:    
        if response['task']['status'] == 'RUNNING':
            print('Download from OpenStreetMap is being processed.  Task ID is '+str(taskID)+'.')
        
    return taskID;

def getRepoID(geoserver, auth, workspace, datastore):
    params = {}
    url = geoserver+"rest/workspaces/"+workspace+"/datastores/"+datastore+".json"
    request = make_request(url=url, params=params, auth=auth)

    if request.getcode() != 200:
        raise Exception("Get Task Status Failed: Status Code {0}".format(request.getcode()))

    response = json.loads(request.read())
    repoID = None
    for entry in response['dataStore']['connectionParameters']['entry']:
        if entry['@key'] == 'geogig_repository':
            repoID = entry['$']
            break

    return repoID;
 
def parse_url(url):
    
    if (url is None) or len(url) == 0:
        return None
    
    index = url.rfind('/')

    if index != (len(url)-1):
        url += '/'
    
    return url

def parse_bbox(extent):
    file_extent = "/opt/cybergis-osm-mappings.git/extents/"+extent.replace(":","/")+".txt"
    bbox = None
    with open (file_extent, "r") as f:
        bbox = f.read().replace('\n', '').replace(' ',',')
    return bbox

def parse_mapping(ns_mapping):
    file_mapping = "/opt/cybergis-osm-mappings.git/mappings/"+ns_mapping.replace(":","/")+".json"
    return file_mapping

def run(args):
    #==#
    verbose = args.verbose
    #==#
    geoserver = parse_url(args.geoserver)
    repo = args.repo
    datastore = args.datastore
    workspace = args.workspace
    timeout = args.timeout or 30
    #==#
    authorname = args.authorname
    authoremail = args.authoremail
    #==#
    auth = None
    if args.username and args.password:
      auth = b64encode('{0}:{1}'.format(args.username, args.password))
    #==#
    update = args.update in ["1","y","t","true"]
    bbox = parse_bbox(args.extent)
    mapping = parse_mapping(args.mapping)
    print "=================================="
    print "#==#"
    print "CyberGIS Script / geogig_sync_osm.py"
    print "Downloading Updates from OpenStreetMap"
    print "#==#"

    if repo:
        pass
    elif geoserver and workspace and datastore:
        repo = getRepoID(geoserver, auth, workspace, datastore)
    else:
        print "You need to include the repo id or the datastore name to sync"
    #==#
    url_repo = geoserver+'geogig/'+repo+'/'
    url_tasks = geoserver+'geogig/tasks'
    #==#
    if update:
        pass
    elif bbox and mapping:
       pass
    else:
        return "Update is false and no new data will be brought in because the extent and mapping aren't specified"

    transID = -1
    try:
        transID = beginTransaction(verbose,url_repo, auth)
    except Exception:
        transID = -1
        raise
    
    if transID != -1:
        taskID = -1
        #==#
        #Checkout master branch.  See: https://github.com/boundlessgeo/GeoGig/issues/788
        try:
            branch = checkout(verbose, url_repo, auth, 'master', transID)
            if not branch:
                raise Exception('An error occurred when checking out master.  Cancelling task.')
            taskID = downloadFromOSM(verbose, url_repo, auth, transID, update, mapping, bbox)
        except Exception:
            taskID = -1
            endTransaction(verbose,url_repo, auth, True, transID)
            raise
        
        if taskID != -1:
            waitOnTask(verbose, url_tasks, auth, taskID, timeout)
  
        #==#
        #Checkout master branch.  See: https://github.com/boundlessgeo/GeoGig/issues/788
        try:
            checkout(verbose, url_repo, auth, 'master', transID)
        except Exception:
            pass
 
    try:
        endTransaction(verbose,url_repo, auth, False, transID)
    except Exception:
        pass
    
    print "=================================="

parser = argparse.ArgumentParser(description='Synchronize GeoGig repository with OpenStreetMap (OSM)')

parser.add_argument("update", default= 'true', help="true/false.  Update existing features only or download new features.  If false, extent and mapping are required.")

#
parser.add_argument("--workspace", help="The workspace of the GeoServer data store of the GeoGig repository you want to sync.")
parser.add_argument("--datastore", help="The name of the GeoServer data store of the GeoGig repository you want to sync.")
parser.add_argument("--repo", help="The GeoServer id of the GeoGig repository you want to sync.")

parser.add_argument("--geoserver", help="The url of the GeoServer servicing the GeoGig repository.")
parser.add_argument("--username", help="The username to use for basic auth requests.")
parser.add_argument("--password", help="The password to use for basic auth requests.")
parser.add_argument("--authorname", help="The author name to use when merging non-conflicting branches.")
parser.add_argument("--authoremail", help="The author email to use when merging non-conflicting branches.")
parser.add_argument("--extent", help="The extent of the OpenStreetMap extract. For example, basic:buildings_and_roads.")
parser.add_argument("--mapping", help="The mapping of the OpenStreetMap extract.  For example, dominican_republic:santo_domingo.")
parser.add_argument("--timeout", type=int, default=30, help="The number of seconds to wait for the osm download task to complete before cancelling.  Default is 30 seconds.")
parser.add_argument('--verbose', '-v', default=0, action='count', help="Print out intermediate status messages.")

args = parser.parse_args()
run(args)
