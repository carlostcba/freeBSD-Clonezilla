import os, sys, wget, requests, shutil, json
from bs4 import BeautifulSoup
from zipfile import ZipFile

def download_management(zfs_pool):
    print("Checking for PXE Management Application...", end='', flush=True)
    try:
        website_url = 'https://api.github.com/repos/alexmekic/pxe-server-management/releases'
        latest_version = json.loads(requests.get(website_url).text)[0]['tag_name']
        print("done")
        try:
            print("Downloading and Installing PXE Management Application...")
            url_download = "https://github.com/alexmekic/pxe-server-management/releases/download/" + latest_version + "/pxe_management"
            wget.download(url=url_download, out='/' + zfs_pool + '/pxe_management/pxe_management')
            print("done")
            print("PXE Management Application installed successfully")
        except:
            print("failed")
    except:
        print("failed")

def check_clonezilla(zfs_pool):
    print("Checking for latest version of Clonezilla...", end='', flush=True)
    try:
        website_url = requests.get('https://clonezilla.org/downloads.php')
        soup = BeautifulSoup(website_url.content,'html5lib')
        latest_version = soup.find('a', attrs = {'href':'./downloads/download.php?branch=stable'}).find('font', attrs = {'color':'red'}).text
        print("done")
        if install_clonezilla(latest_version, zfs_pool):
            print("Clonezilla " + latest_version + " installed successfully")
        else:
            print("Clonezilla install failed")
    except:
        print("failed")

def install_clonezilla(latest_version, zfs_pool):
    print("Downloading Clonezilla...")
    url_download = 'https://sourceforge.net/projects/clonezilla/files/clonezilla_live_stable/' + str(latest_version) + '/clonezilla-live-' + str(latest_version) + '-amd64.zip/download'
    try:
        wget.download(url=url_download, out='/' + zfs_pool + '/tftp/clonezilla_update.zip')
        print('done')
        print('Installing Clonezilla...', end='', flush=True)
        shutil.rmtree('/' + zfs_pool + '/tftp/clonezilla')  
        os.mkdir('/' + zfs_pool + '/tftp/clonezilla')
        with ZipFile('/' + zfs_pool + '/tftp/clonezilla_update.zip', 'r') as zipObj:
            zipObj.extractall('/' + zfs_pool + '/tftp/clonezilla')
        print('done')
        print('Cleaning up download file...', end='', flush=True)
        os.remove('/' + zfs_pool + '/tftp/clonezilla_update.zip')
        print('done')
        return True
    except:
        print("failed")
        return False

if __name__ == "__main__":
    zfs_pool = sys.argv[1]
    download_management(zfs_pool)
    check_clonezilla(zfs_pool)
