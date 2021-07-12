// == begin utils.js

// begin html escape hack (credit stacko)
// only works with createElement #backlog
if (document.createElement) {
	var escapeTA = document.createElement('textarea');
}
function escapeHTML(html) {
	if (window.escapeTA) {
		escapeTA.textContent = html;
		return escapeTA.innerHTML;
	}
}
function unescapeHTML(html) {
	if (window.escapeTA) {
		escapeTA.innerHTML = html;
		return escapeTA.textContent;
	}
}
// end html escape hack

function OnLoadEverything () { // checks for each onLoad function and calls it
// keywords: OnLoadAll BodyOnLoad body onload body.onload
// typically called from body.onload
	//alert('DEBUG: OnLoadEverything() begins');

	if (window.setClock) {
		//alert('DEBUG: OnLoadEverything: setClock()');
		window.eventLoopSetClock = 1;
		setClock();
	}
	if (window.ItsYou) {
		//alert('DEBUG: OnLoadEverything: ItsYou()');
		ItsYou();
	}
	if (window.ShowTimestamps) {
		//alert('DEBUG: OnLoadEverything: ShowTimestamps()');
		window.eventLoopShowTimestamps = 1;
		ShowTimestamps();
	}
	if (window.SettingsOnload) {
		//alert('DEBUG: OnLoadEverything: SettingsOnload()');
		SettingsOnload();
	}
	if (window.ProfileOnLoad) {
		//alert('DEBUG: OnLoadEverything: ProfileOnLoad()');
		ProfileOnLoad();
	}
	if (window.WriteOnload) {
		//alert('DEBUG: OnLoadEverything: WriteOnload()');
		WriteOnload();
	}

	if (window.ShowAdvanced) {
		//alert('DEBUG: OnLoadEverything: ShowAdvanced()');
		window.eventLoopShowAdvanced = 1;
		ShowAdvanced(0);
	}
	//alert('DEBUG: OnLoadEverything: ShowAdvanced() finished!');

	if (window.SearchOnload) {
		//alert('DEBUG: OnLoadEverything: SearchOnload()');
		SearchOnload();
	}
	if (window.UploadAddImagePreviewElement) {
		//alert('DEBUG: OnLoadEverything: UploadAddImagePreviewElement()');
		UploadAddImagePreviewElement();
	}

	//alert('DEBUG: OnLoadEverything: checking for editable field...');

	if (window.location && document.compose && window.location.href.indexOf) {
		if (
			window.location &&
			window.location.href &&
			window.location.href.indexOf('write') != -1 ||
			window.location.hash.indexOf('reply') != -1 ||
			(
				window.location.href.indexOf('message') != -1 &&
				window.GetPrefs &&
				GetPrefs('focus_reply')
			)
				&&
			document.compose &&
			document.compose.comment &&
			document.compose.comment.focus
		) {
			//alert('DEBUG: OnLoadEverything: document.compose.comment.focus()()');
			document.compose.comment.focus();
		}
	}

	if (window.location.href && (window.location.href.indexOf('search') != -1) && document.search.q) {
		//alert('DEBUG: OnLoadEverything: document.search.q.focus()');
		document.search.q.focus();
	}
	if (window.EventLoop) {
		//alert('DEBUG: OnLoadEverything: EventLoop()');
		if (window.CheckIfFresh) {
			window.eventLoopFresh = 1;
		}
		window.eventLoopEnabled = 1;
		EventLoop();
	}
	if (window.DraggingInit && GetPrefs('draggable')) {
		//alert('DEBUG: OnLoadEverything: DraggingInit()');
		if (window.location.href.indexOf('settings') != -1) {
			// exclude settings page to aid user in escaping a fucked up situation
			DraggingInit(0);
		} else {
			DraggingInit(1);
		}
	}
	if (window.HideLoadingIndicator) {
		//alert('DEBUG: OnLoadEverything: HideLoadingIndicator()');
		HideLoadingIndicator();
	}

	// everything is set now, start event loop
	//
} // OnLoadEverything()

function ShowPreNavigateNotification () { // displays 'Meditate...' message
	// OnUnload ()
	//alert('DEBUG: ShowPreNavigateNotification() begin');

	if (window.blockPreNavigateNotification) {
		//alert('DEBUG: ShowPreNavigateNotification() blocked by window.blockPreNavigateNotification');
		window.blockPreNavigateNotification = 0;
		return '';
	}

	if (document.title.indexOf('...') == -1) {
		document.title = document.title + '...';
	}

	//document.body.style.opacity="0.8";
	if (event.target == location.href) {
	} else {
		if (document.getElementById) {
			var ariaAlert;
			ariaAlert = document.getElementById('ariaAlert');

			if (!ariaAlert) {
				ariaAlert = document.createElement('p');
				ariaAlert.setAttribute('role', 'alert');
				ariaAlert.setAttribute('id', 'ariaAlert');
				ariaAlert.innerHTML = 'Meditate...';
				ariaAlert.style.opacity = '1';
				ariaAlert.style.zIndex = '1337';
				//document.body.appendChild(ariaAlert);
				document.body.insertBefore(ariaAlert, document.body.firstChild);
			}
		} else {
			//#todo
		}
	}

	return ''; // true would show a confirmation
} // ShowPreNavigateNotification()

if (!window.performanceOptimization && window.GetPrefs) {
	window.performanceOptimization = GetPrefs('performance_optimization');
}

function EventLoop () { // for calling things which need to happen on a regular basis
// sets another timeout for itself when done
// replaces several independent timeouts
// #backlog add secondary EventLoopWatcher timer which ensures this one runs when needed

	var d = new Date();
	var eventLoopBegin = d.getTime(); // eventLoopStart

	if (!window.eventLoopPrevious) {
		window.eventLoopPrevious = 1;
	}
	window.eventLoopBegin = eventLoopBegin;

	if (window.eventLoopSetClock && window.setClock) {
		setClock();
	}

	var m = 1000; // multiplier for performance thresholds
	if (window.performanceOptimization) {
		if (window.performanceOptimization == 'quicker') {
			m = 1;
		}
		if (window.performanceOptimization == 'none') {
			// this is the 'None' setting in Settings
			m = 0;
			return '';
		}
	}

	//alert('DEBUG: EventLoop: eventLoopBegin = ' + eventLoopBegin + ' - window.eventLoopPrevious = ' + window.eventLoopPrevious + ' = ' + (eventLoopBegin - window.eventLoopPrevious));

	if (10*m < (eventLoopBegin - window.eventLoopPrevious)) {
		window.eventLoopPrevious = eventLoopBegin;

		if (window.flagUnloaded) {
			if (window.ShowPreNavigateNotification) {
				ShowPreNavigateNotification();
			}
		}

		//return;
		// uncomment to disable event loop
		// makes js debugging easier

		if (window.eventLoopShowTimestamps && window.ShowTimestamps) {
			if (13*m < (eventLoopBegin - window.eventLoopShowTimestamps)) {
				ShowTimestamps();
				window.eventLoopShowTimestamps = eventLoopBegin;
			} else {
				// do nothing
			}
		}

		if (window.eventLoopDoAutoSave && window.DoAutoSave) {
			if (5*m < (eventLoopBegin - window.eventLoopDoAutoSave)) { // autosave interval
				DoAutoSave();
				window.eventLoopDoAutoSave = eventLoopBegin;
			} else {
				// do nothing
			}
		}

		if (window.eventLoopShowAdvanced && window.ShowAdvanced) {
			ShowAdvanced();
		}

		if (window.eventLoopFresh && window.CheckIfFresh) {
			if (10000 < (eventLoopBegin - window.eventLoopFresh)) {
			//if (10*m < (eventLoopBegin - window.eventLoopFresh)) {
			// this is commented because it may hammer the server. uncomment if using localhost

				//window.eventLoopFresh = eventLoopBegin;
				if (
					window.eventLoopFresh &&
					(!window.GetPrefs || GetPrefs('notify_on_change'))
				) {
					CheckIfFresh();
					window.eventLoopFresh = eventLoopBegin;
				}
			}
		}

		if (window.GetPrefs) {
			window.performanceOptimization = GetPrefs('performance_optimization');
		}
	} // 10000 < (eventLoopBegin - window.eventLoopPrevious)

	if (window.eventLoopEnabled) {
		// this sets the next setTimeout for the next "loop" iteration

		// see how long this last iteration took
		var d = new Date();
		var eventLoopEnd = d.getTime();
		var eventLoopDuration = eventLoopEnd - eventLoopBegin;
		//document.title = eventLoopDuration; // for debugging performance

		// unset any timeout if already set
		if (window.timeoutEventLoop) {
			clearTimeout(window.timeoutEventLoop);
		}

		if (30 < eventLoopDuration) {
			// if loop went longer than 100ms, run every 3 seconds or more
			//document.title = eventLoopDuration;
			
			if (GetPrefs('notify_event_loop')) {
				displayNotification('EventLoop: ' + eventLoopDuration + 'ms');
			}
//
//			// #todo make it known to user that hitting performance limit
//			if (document.title.substr(0,3) != '/ ') {
//				// for now we just prepend the title with a slash
//				document.title = '/ ' + document.title;
//			}

			// set performance setting to 'faster'

			//SetPrefs('performance_optimization', 'faster');
			eventLoopDuration = eventLoopDuration * 10;
		} else {
			// otherwise run again after 1 interval time
			eventLoopDuration = 1*m;
		}

		window.timeoutEventLoop = setTimeout('EventLoop()', eventLoopDuration);
	} // window.eventLoopEnabled

	return '';

} // EventLoop()

function UrlExists (url) { // checks if url exists
// #todo use async
// #todo Q: how to do pre-xhr browsers? A: use img.src = and check the resulting image url

    //alert('DEBUG: UrlExists(' + url + ')');

	if (window.XMLHttpRequest) {
	    //alert('DEBUG: UrlExists: window.XMLHttpRequest check passed');

		var http = new XMLHttpRequest();
		http.open('HEAD', url, false);
		//http.timeout = 5000; //#xhr.timeout
		http.send();
		var httpStatusReturned = http.status;

		//alert('DEBUG: UrlExists: httpStatusReturned = ' + httpStatusReturned);

		return (httpStatusReturned == 200);
	}
}
//
//function UrlExists2(url, callback) { // checks if url exists
//// todo use async and callback
//// todo how to do pre-xhr browsers?
//    //alert('DEBUG: UrlExists(' + url + ')');
//
//	if (window.XMLHttpRequest) {
//	    //alert('DEBUG: UrlExists: window.XMLHttpRequest check passed');
//
//        var xhttp = new XMLHttpRequest();
//        xhttp.onreadystatechange = function() {
//    if (this.readyState == 4 && this.status == 200) {
//       // Typical action to be performed when the document is ready:
//       document.getElementById("demo").innerHTML = xhttp.responseText;
//    }
//};
//xhttp.open("GET", "filename", true);
//xhttp.send();
//
//
//
//		var http = new XMLHttpRequest();
//		http.open('HEAD', url, false);
//		http.send();
//		var httpStatusReturned = http.status;
//
//		//alert('DEBUG: UrlExists: httpStatusReturned = ' + httpStatusReturned);
//
//		return (httpStatusReturned == 200);
//	}
//}

function DisplayStatus(status) {
	if (document.getElementById) {
		var statusBar = document.getElementById('status');

	}
}

function DownloadAsTxt(filename, text) {
    var element = document.createElement('a');

    element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
    element.setAttribute('download', filename);

    element.style.display = 'none';
    document.body.appendChild(element);

    element.click();

    document.body.removeChild(element);
}


function displayNotification (strMessage, thisButton) { // adds notificatin to page
// showNotification (
// used for loading indicator bar (to top of page, depending on style)
// also used for "creating profile" and "already voted" notifications
	var spanNotification = document.createElement('span');
	spanNotification.setAttribute('class', 'notification');
	spanNotification.setAttribute('role', 'alert');
	spanNotification.setAttribute('onclick', 'this.remove(); return false;');
	spanNotification.innerHTML = strMessage;

	if (thisButton) {
		thisButton.parentNode.appendChild(spanNotification);
		thisButton.after(spanNotification);
	} else {
		// #todo this should be in stylesheet; floating notification should have different class
		spanNotification.style.position = 'fixed';
		spanNotification.style.top = '0';
		spanNotification.style.right = '0';
		spanNotification.style.margin = '0';

		document.body.appendChild(spanNotification);

	}
} // displayNotification()

function newA (href, target, innerHTML, parent) { // makes new a element and appends to parent
	var newLink = document.createElement('a');
	if (href) { newLink.setAttribute('href', href); }
	if (target) { newLink.setAttribute('target', target); }
	if (innerHTML) { innernewLink.setAttribute('innerHTML', innerHTML); }
	parent.appendChild(newLink);
	return newLink;
}

function SetCookie (cname, cvalue, exdays) { // set cookie
	//alert('DEBUG: SetCookie(' + cname + ', ' + cvalue + ', ' + exdays + ')');
	var d = new Date();
	if (!exdays) {
		exdays = 1;
	}
	d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
	var expires = "expires=" + d.toUTCString();
	document.cookie = cname + "=" + cvalue + ";" + expires + ";path=/";
	var testSetCookie = GetCookie(cname);
	if (cvalue == testSetCookie) {
		return 1;
	} else {
		return 0;
	}
} // SetCookie()

function GetCookie (cname) { // get cookie value
	// in js, cookies are accessed via one long string of the form
	// key1=value1; key2=value2;
	// so we make an array, splitting the string using the ; separator
	var ca = document.cookie.split(';');

	// the value we are looking for will be prefixed with cname=
	var name = cname + "=";

	for(var i = 0; i < ca.length; i++) {
		// loop through ca array until we find prefix we are looking for
		var c = ca[i];
		while (c.charAt(0) == ' ') {
			// remove any spaces at beginning of string
			c = c.substring(1);
		}
		if (c.indexOf(name) == 0) {
			// if prefix matches, return value
			return c.substring(name.length, c.length);
		}
	}

	// at this point, nothing left to do but return empty string
	return "";
}

function UnmaskBlurredImages () {
	var im = document.images;
	if (im) {
		var i = 0;
		for (i = 0; i < im.length; i++) {
			if (im[i].getAttribute('src')) {
				var src = im[i].getAttribute('src');
				var gPos = src.indexOf('_g_');
				if (gPos != -1 && 0 < gPos) {
					im[i].setAttribute('src', src.substr(0, gPos) + '' + src.substr(gPos + 2));
				}
			}
		}
	}
	return '';
} // UnmaskBlurredImages()


//https://stackoverflow.com/questions/123999/how-can-i-tell-if-a-dom-element-is-visible-in-the-current-viewport

function elementInViewport(el) {
  var top = el.offsetTop;
  var left=el.offsetLeft;
  var width = el.offsetWidth;
  var height = el.offsetHeight;

  while(el.offsetParent) {
    el = el.offsetParent;
    top += el.offsetTop;
    left+=el.offsetLeft;
  }

  return (
    window.pageYOffset <= top &&
    window.pageXOffset <= left &&
    (top + height) <= (window.pageYOffset + window.innerHeight) &&
    (left + width) <= (window.pageXOffset + window.innerWidth)
  );
}
//You could modify this simply to determine if any part of the element is visible in the viewport:

function elementInViewport2(el) {
  var top = el.offsetTop;
  var left=el.offsetLeft;
  var width = el.offsetWidth;
  var height = el.offsetHeight;

  while(el.offsetParent) {
    el = el.offsetParent;
    top += el.offsetTop;
    left+=el.offsetLeft;
  }

  return (
    top < (window.pageYOffset + window.innerHeight) &&
    left < (window.pageXOffset + window.innerWidth) &&
    window.pageYOffset < (top + height) &&
    window.pageXOffset < (left + width)
  );
}


//function ChangeInputToTextarea (input) { // called by onpaste
////#input_expand_into_textarea
//	//#todo more sanity
//	if (!input) {
//		return '';
//	}
//
//	if (document.createElement) {
//		var parent = input.parentElement;
//		var textarea = document.createElement('textarea');
//		var cols = input.getAttribute('cols');
//		var name = input.getAttribute('name');
//		var id = input.getAttribute('id');
//		var rows = 5;
//		var width = cols + 'em';
//
//		textarea.setAttribute('name', name);
//		textarea.setAttribute('id', id);
//		textarea.setAttribute('cols', cols);
//		textarea.setAttribute('rows', rows);
//		//textarea.style.width = width;
//		textarea.innerHTML = input.value;
//
//		//parent.appendChild(t);
//		parent.insertBefore(textarea, input.nextSibling);
//		input.style.display = 'none';
//
//		textarea.focus();
//		textarea.selectionStart = textarea.innerHTML.length;
//		textarea.selectionEnd = textarea.innerHTML.length;
//
//		if (window.inputToChange) {
//			window.inputToChange = '';
//		}
//	}
//
//	return true;
//}

//
//function ConvertSubmitsToButtonsWithAccessKey (parent) {
//	if (!parent) {
//		//alert('DEBUG: ConvertSubmitsToButtons: warning: sanity check failed');
//		return '';
//	}
//
//	if (parent.getElementsByClassName) {
//		var buttons = parent.getElementsByClassName('btnSubmit');
//		// convert each submit to button with accesskey
//	} else {
//		//todo
//	}
//	return ''
//} // ConvertSubmitsToButtonsWithAccessKey()


// developer
// SetPrefs('notify_event_loop', 1);
// SetPrefs('notify_event_loop', 0);


// == end utils.js