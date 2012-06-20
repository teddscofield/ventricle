Ventricle
=========
Pumps CSS, markup, and image changes to the browser in real time.

Overview
--------
This tool lets you see changes to a web page you're developing in multiple open browsers, on multiple machines even, in real time.  So you can have Chrome, FireFox, IE7/8/9, Safari, etc. all open to the page under construction and see the effect of changing a style in real time instead of having to tab around and hitting refresh.

CSS changes are reloaded in without refreshing the page. JavaScript and markup changes require a page refresh so in some cases this tool may not super helpful (e.g. the page cannot be simply refreshed or takes a really long time to load).

Incomplete Usage Example
------------------------
Scenario looks this:
Dev site: local.dev  (running through a local Apache instance)
Site files: /var/www

Step 1)
  - in /var/www create a symbolic link to the ventricle installs resources folder.  For example:
cd /var/www
ln -s /usr/lib/node_modules/ventricle/resources/ ventricle
TODO:  this isn't a good idea, only serves for getting things to come alive.  Try an Apache proxy rule next.


  - in the html file you are working out of, add this java script include:
<script type="text/javascript" src="http://local.dev:4567/ventricle/js/subscribe.js"></script>

  - start Ventricle with this command line:
ventricle http://local.dev?/var/www

  - edit a css or html file underneath /var/www.

Step 2)
  - ???

Step 3)
  - profit!
  
As soon as you save the file, the browser *should* refresh or reload it automatically.

Dependencies
------------
Currently you need nodejs and git in order to use Ventricle.

  * nodejs - http://www.nodejs.org/#download
  * git - http://git-scm.com/downloads
  
Known Issues
------------
  * Windows not yet supported.  Those brave enough to try to work on the tool (not with it) in windows will need to use the Git Bash shell that comes with the git windows install.
  * First time use of the npm install may result in an error (e.g. ERR! TypeError: Cannot call method 'forEach' of undefined).  Try re-running the npm install command to work around.