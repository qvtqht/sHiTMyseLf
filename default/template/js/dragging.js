/* dragging.js */
// allows dragging of boxes on page with the mouse pointer

/*
	known issues:
	* problem: syntax errors on older browsers like netscape and ie3
	  proposed solution: remove nested function declarations
	  -or-

	* problem: no keyboard alternative at this time
	  proposed solution: somehow allow moving through windows and moving them with keyboard

	* problem: slow and janky, needs more polish
	  proposed solution: optimizations, more elbow grease
*/

// props https://www.w3schools.com/howto/howto_js_draggable.asp

/*
		#mydiv {
    	  	position: absolute;
     		z-index: 9;
    	}
    	
    	#mydivheader {
    		this is just the titlebar
    	}
*/

window.draggingZ = 0; // keeps track of the topmost box's zindex
// incremented whenever dragging is initiated, that way element pops to top

function dragElement (elmnt, header) { // initialize draggable state for dialog
	//alert('DEBUG: dragElement()');

	var pos1 = 0, pos2 = 0, pos3 = 0, pos4 = 0;
	if (header) {
		// if present, the header is where you move the DIV from:
		header.onmousedown = dragMouseDown;
	} else {
		// otherwise, move the DIV from anywhere inside the DIV:
		elmnt.onmousedown = dragMouseDown;
	}

	// set element's position based on its initial box model position
	var rect = elmnt.getBoundingClientRect();
	elmnt.style.top = (rect.top) + "px";
	elmnt.style.left = (rect.left) + "px";
	elmnt.style.position = 'absolute';
	elmnt.style.display = 'table';

    //console.log(rect.top, rect.right, rect.bottom, rect.left);
	//elmnt.style.position = 'absolute';
	//elmnt.style.z-index = '9';

	function dragMouseDown(e) {
		//alert('DEBUG: dragMouseDown');
		//SetActiveDialog(elmnt);
		window.dialogDragInProgress = 1;

		e = e || window.event;
		e.preventDefault();
		// get the mouse cursor position at startup:
		pos3 = e.clientX;
		pos4 = e.clientY;

		document.onmouseup = closeDragElement;
		// call a function whenever the cursor moves:
		document.onmousemove = elementDrag;
	}

	function elementDrag(e) {
		//alert('DEBUG: elementDrag');
		//document.title = pos1 + ',' + pos2 + ',' + pos3 + ',' + pos4;
		//document.title = e.clientX + ',' + e.clientY;
		//document.title = elmnt.offsetTop + ',' + elmnt.offsetLeft;
		e = e || window.event;
		e.preventDefault();
		// calculate the new cursor position:
		pos1 = pos3 - e.clientX;
		pos2 = pos4 - e.clientY;
		pos3 = e.clientX;
		pos4 = e.clientY;
		// set the element's new position:

		elmnt.style.top = (elmnt.offsetTop - pos2) + "px";
		elmnt.style.left = (elmnt.offsetLeft - pos1) + "px";
	}

	function closeDragElement() {
		//alert('DEBUG: closeDragElement');
		window.dialogDragInProgress = 0;

		// stop moving when mouse button is released:
		document.onmouseup = null;
		document.onmousemove = null;

		SaveDialogPosition(elmnt);
	}
} // dragElement()

function SaveDialogPosition (elmnt) {
// function SaveWindowPosition ()
	if (elmnt) {
		var elId = GetDialogId(elmnt);

		if (elId && elId.length < 31) {
			SetPrefs(elId + '.style.top', elmnt.style.top);
			SetPrefs(elId + '.style.left', elmnt.style.left);
		} else {
			//alert('DEBUG: SaveDialogPosition: warning: elId is false');
		}
	} else {
		//alert('DEBUG: SaveDialogPosition: warning: elmnt is false');
	}
} // SaveDialogPosition()

function DraggingSaveAllDialogPositions () {
	//alert('DEBUG: DraggingSaveAllDialogPositions()');
	var elements = document.getElementsByClassName('dialog');

	for (var i = elements.length - 1; 0 <= i; i--) {
		SaveDialogPosition(elements[i]);
	}
} // DraggingSaveAllDialogPositions()

function DraggingRetile () {
	//alert('DEBUG: DraggingRetile()');
	var elements = document.getElementsByClassName('dialog');

	for (var i = elements.length - 1; 0 <= i; i--) {
		if (elements[i].getAttribute('id') == '391a572a') {
			// controls dialog
		} else {
			elements[i].style.position = 'static';
			elements[i].style.display = 'inline-block';
		}
	}
//	for (var i = elements.length - 1; 0 <= i; i--) {
//		var newTop = elements[i].style.top;
//		var newLeft = elements[i].style.left;
//		elements[i].style.position = 'absolute';
//		elements[i].style.top = newTop;
//		elements[i].style.left = newLeft;
//	}
//
//	DraggingInit(0);
}

function SetActiveDialog (ths) {
// ActivateDialog {
// FocusMe ShowMe ActivateMe {

	if (!window.GetPrefs || !GetPrefs('draggable')) {
		// #todo optimize
		return '';
	}

	if (ths.getAttribute('imactive') == '1' || window.dialogDragInProgress) {
		//alert('DEBUG: SetActiveDialog: imactive found');
		return true;
	} else {
		//alert('DEBUG: SetActiveDialog: imactive NOT found');
	}

	//alert('DEBUG: SetActiveDialog(ths = ' + ths + ')');
		// #thoughts should this be dependent on GetPrefs?
		// or should it unintentionally come on if GetPrefs is not available?

	ths.style.zIndex = ++window.draggingZ;

	var colorWindow = ''; // for templating
	var colorTitlebar = ''; // for templating
	var colorSecondary = ''; // for templating
	var colorTitlebarText = ''; // for templating

	var doScale = 1; // config/admin/js/dragging_do_scale
	var scaleLarge = '2.0';
	var scaleSmall = '1.0';
	// this doesn't work right  yet, but loks promising

	var elements = document.getElementsByClassName('dialog');
	for (var i = 0; i < elements.length; i++) {
	// for (var i = elements.length - 1; 0 <= i; i--) { // walk backwards for positioning reasons
		// walking backwards is necessary to preserve the element positioning on the page
		// once we remove the element from the page flow, all the other elements reflow to account it
		// if we walk forwards here, all the elements will end up in the top left corner
		if (elements[i] == ths) {
			elements[i].setAttribute('imactive', '1');
			elements[i].style.borderColor = colorTitlebar;

			//var comStyle = window.getComputedStyle(elements[i], null);
			//var iwidth = parseInt(comStyle.getPropertyValue("width"), 10);
			//var iheight = parseInt(comStyle.getPropertyValue("height"), 10);
			////alert('DEBUG: SetActiveDialog: iwidth: ' + document.documentElement.clientWidth + ', iheight:' + iheight);
			////alert('DEBUG: SetActiveDialog: document.documentElement.clientWidth and .clientHeight: ' + document.documentElement.clientWidth + ',' + document.documentElement.clientHeight);
			////alert('DEBUG: SetActiveDialog: myScale = ' + myScale);

			if (doScale) {
                //var myScale = 1 + (document.documentElement.clientWidth / (iwidth * 3));
                var myScale = scaleLarge;

				elements[i].style.transition = 'transform 0.15s';
				//elements[i].style.transform = 'scale(' + myScale + ')';
				elements[i].style.transform = 'scale(' + myScale + ')';
				elements[i].style.transformOrigin = 'top left';

				var css = window.getComputedStyle(elements[i]);
//				document.title =
//					css.getPropertyValue('top') +
//					',' +
//					css.getPropertyValue('left') +
//					',' +
//					css.getPropertyValue('height') +
//					',' +
//					css.getPropertyValue('width') +
//					'...'
//				;
			}
		} else {
			elements[i].setAttribute('imactive', '0');
			elements[i].style.borderColor = colorWindow;
			if (doScale) {
				//var myScale =(document.documentElement.clientWidth / (iwidth * 5));
				var myScale = scaleSmall;
				elements[i].style.transform = 'scale(' + myScale + ')';
				elements[i].style.transformOrigin = 'top left';

				//elements[i].style.transform = 'scale(0.5)';
				//elements[i].style.transformOrigin = 'top center';

			}
		}

		var allTitlebar = elements[i].getElementsByClassName('titlebar'); // #todo factor out
		var firstTitlebar = allTitlebar[0];

		if (firstTitlebar && firstTitlebar.getElementsByTagName) {
			if (elements[i] == ths) {
				// active
				firstTitlebar.style.backgroundColor = colorTitlebar;
				firstTitlebar.style.color = colorTitlebarText;
				//elements[i].style.boxShadow = '0 0 15pt #335555;';
			} else {
				// inactive
				firstTitlebar.style.backgroundColor = colorSecondary;
				firstTitlebar.style.color = colorWindow;
				//elements[i].style.boxShadow = '';
			}
		}
	}

	return true;
} // SetActiveDialog()

function DraggingCascade () {
	//alert('DEBUG: DraggingCascade()');
	
	var titlebarHeight = 0;

	var curTop = 55;
	var curLeft = 5;
	var curZ = 0;

	var elements = document.getElementsByClassName('dialog');
	for (var i = 0; i < elements.length; i++) {
	// for (var i = elements.length - 1; 0 <= i; i--) { // walk backwards for positioning reasons
		// walking backwards is necessary to preserve the element positioning on the page
		// once we remove the element from the page flow, all the other elements reflow to account it
		// if we walk forwards here, all the elements will end up in the top left corner

		var allTitlebar = elements[i].getElementsByClassName('titlebar'); // #todo factor out
		var firstTitlebar = allTitlebar[0];

		var allMenubar = elements[i].getElementsByClassName('menubar');
		var firstMenubar = allMenubar[0];

		titlebarHeight = 30;

		if (firstMenubar) {
			elements[i].style.zIndex = 1337;
		} else {
			if (firstTitlebar && firstTitlebar.getElementsByTagName) {
				// dragElement(elements[i], firstTitlebar);

				elements[i].style.top = curTop + 'px';
				elements[i].style.left = curLeft +'px';
				elements[i].style.zIndex = curZ;

				curZ++;
				curTop += titlebarHeight;
				curLeft += titlebarHeight;
			}
		}
	}
} // DraggingCascade()

function DraggingInitDialog (el, doPosition) {
// DraggingInitElement () {
	// #todo sanity
		var elId = GetDialogId(el);

		//alert('DEBUG: DraggingInit: elId = ' + elId);

		// find all titlebars and remember the first one
		var allTitlebar = el.getElementsByClassName('titlebar');
		var firstTitlebar = allTitlebar[0];

		if (firstTitlebar) {
			dragElement(el, firstTitlebar);
		} else {
			//alert('DEBUG: DraggingInit: warning: titlebar missing!');
			dragElement(el, el);
		}

		if (elId && elId.length < 31) { // RestoreWindowPosition {
			if (doPosition) {
				RestoreDialogPosition(el, elId);

				if (GetPrefs(elId + '.collapse') == 'none') {
					CollapseWindow(el, 'none'); //#meh
				} else {
					//ok
				}
			} else {
				// cool
			}
		} else {
			//alert('DEBUG: DraggingInit: warning: elId is false 2' + elements[i].innerHTML);
		}
		//elements[i].style.display = 'table !important';
} // DraggingInitDialog()

function DraggingInit (doPosition) { // initialize all class=dialog elements on the page to be draggable
// InitDrag {
// DragInit {
// initialize all class=dialog elements on the page to be draggable

	//alert('DEBUG: DraggingInit()');

	if (!document.getElementsByClassName) {
		// feature check
		//alert('DEBUG: DraggingInit: feature check failed');
		return '';
	}

	//if (window.GetPrefs && !GetPrefs('draggable')) {
	//	//alert('DEBUG: DraggingInit: warning: GetPrefs(draggable) was false, returning');
	//	return '';
	//}

	var doPosition = 1; // ATTENTION THIS IS TEMPLATED!

	// find all class=dialog elements and walk through them
	var elements = document.getElementsByClassName('dialog');
	for (var i = elements.length - 1; 0 <= i; i--) { // walk backwards for positioning reasons
		// walking backwards is necessary to preserve the element positioning on the page
		// once we remove the element from the page flow, all the other elements reflow to account it
		// if we walk forwards here, all the elements will end up in the top left corner
		window.draggingZ++;

		DraggingInitDialog(elements[i], doPosition);

	} // for i in elements
} // DraggingInit()

function RestoreDialogPosition (el, elId) {
	//alert('DEBUG: RestoreDialogPosition()');
	if (!elId) {
		elId = GetDialogId(el);
	}

	var newTop = GetPrefs(elId + '.style.top');
	if (newTop) {
		el.style.top = GetPrefs(elId + '.style.top');
	}
	var newLeft = GetPrefs(elId + '.style.left');
	if (newLeft) {
		el.style.left = newLeft;
	}
} // RestoreDialogPosition()

function GetDialogId (win) { // returns dialog id (based on id= or title bar caption)
	//alert('DEBUG: GetDialogId()');
	if (win && win.getElementsByClassName) {
		if (win && win.getAttribute && win.getAttribute('id')) {
			// easy
			//alert('DEBUG: GetDialogId: returning win.getAttribute(id) = ' + win.getAttribute('id') );
			return win.getAttribute('id');

		} else {
			// hard
			//alert('DEBUG: GetDialogId: hard mode!');

			var allTitlebar = win.getElementsByClassName('titlebar');
			var firstTitlebar = allTitlebar[0];

			if (firstTitlebar && firstTitlebar.getElementsByTagName) {
				var elId = firstTitlebar.getElementsByTagName('b');
				if (elId && elId[0]) {
					elId = elId[0];

					if (elId && elId.innerHTML) {
						if (elId.innerHTML.length <= 31) {
							//alert('DEBUG: GetDialogId: returning elId.innerHTML = ' + elId.innerHTML );

							return elId.innerHTML;
						} else {
							//alert('DEBUG: GetDialogId: returning elId.innerHTML.substr(0, 31) = ' + elId.innerHTML.substr(0, 31));

							return elId.innerHTML.substr(0, 31);
						}
					}
				}
			}
		}
	} else {
		//alert('GetDialogId: warning: fallback');
	}
	return '';
} // GetDialogId()

function CollapseWindow (p, newVisible) { // collapses or expands specified window/dialog
	//alert('DEBUG: CollapseWindow()');
	if (p.getElementsByClassName) {
		var content = p.getElementsByClassName('content');
		if (content.length) {
			SetElementVisible(content[0], newVisible);
		}
		content = p.getElementsByClassName('menubar');
		if (content.length) {
			SetElementVisible(content[0], newVisible);
		}
		content = p.getElementsByClassName('heading');
		if (content.length) {
			SetElementVisible(content[0], newVisible);
		}
		content = p.getElementsByClassName('statusbar');
		if (content.length) {
			SetElementVisible(content[0], newVisible);
		}

		var btnSkip = p.getElementsByClassName('btnSkip');
		if (btnSkip && btnSkip[0]) {
			if (newVisible == 'none') {
				btnSkip[0].innerHTML = '}-{';
			} else {
			    btnSkip[0].innerHTML = '{-}';
			}
		}

		return false;
	}

	return true;
} // CollapseWindow()

function CollapseWindowFromButton (t) { // collapses or expands window based on button pressed (t)
// t is presumed to be clicked element's this, but can be any other element
// if t's caption is 'v', window is re-expanded
// if 'x' (or anything else) collapses window
// this is done by navigating up until a table is reached
// and then hiding the first class=content element within
// presumably a TR but doesn't matter really because SetElementVisible() is used
// pretty basic, but it works.
	if (t.innerHTML && t.firstChild) {
		if (t.firstChild.nodeName == 'FONT') {
			// small hack in case link has a font tag inside
			// the font tag is typically used to style the link a different color for older browsers
			t = t.firstChild;
		}
		var newVisible = 'initial';
		if (t.innerHTML == '}-{') { //#collapseButton
			//currently collapsed, expand
			t.innerHTML = '{-}'; // //#collapseButton
		} else {
			// currently expanded, collapse
			t.innerHTML = '}-{'; //#collapseButton
			newVisible = 'none';
		}
		if (t.parentElement) {
			//hide content elements
			var p = t;

			var sanityCounter = 20;

			while (p.nodeName != 'TABLE') {
				p = p.parentElement;
				sanityCounter--;
				if (sanityCounter < 1) {
					//alert('DEBUG: CollapseWindowFromButton: warning: sanity check failed');
					return '';
				}
			}

			var winId = GetDialogId(p);
			SetPrefs(winId + '.collapse', newVisible);

			return CollapseWindow(p, newVisible);
		}
	}
	return true;
} // CollapseWindowFromButton()

function SelectMe (ths) {
	// not worky yet

	//alert('DEBUG: SelectMe()');
	if (!ths) {
		//alert('DEBUG: SelectMe: warning: ths missing');
		return '';
	}

    if (window.getSelection && document.createRange) {
        var selection = window.getSelection();
        var range = document.createRange();
        range.selectNodeContents(ths);
        selection.removeAllRanges();
        selection.addRange(range);
    } else if (document.selection && document.body.createTextRange) {
        var range = document.body.createTextRange();
        range.moveToElementText(ths);
        range.select();
    }

    return true;
} // SelectMe()

function InsertFetchedDialog () {
	//alert('DEBUG: InsertFetchedDialog()');

	var xmlhttp = window.xmlhttp2;
	if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
		//alert('DEBUG: InsertFetchedDialog: found status 200');

		var inject = document.createElement('span'); // temporary
		inject.innerHTML = xmlhttp.responseText;
		document.body.appendChild(inject);

		var newDialog = inject.getElementsByClassName('dialog');
		//alert('DEBUG: InsertFetchedDialog: newDialog.length = ' + newDialog.length);
		//alert('DEBUG: InsertFetchedDialog: newDialog = ' + newDialog);

		//var actualDialog = newDialog.firstElement;
		////alert('DEBUG: InsertFetchedDialog: actualDialog = ' + actualDialog);
		if (window.DraggingInit) {
			DraggingInit(0);
		}
		if (window.ShowTimestamps) {
			ShowTimestamps();
		}

		if (newDialog.length) {
			SetActiveDialog(newDialog[0]);
		}

/*
		var newDialog = inject.getElementsByClassName('dialog');
		if (!newDialog) {
			newDialog = inject.getElementsByTagName('form');
		}
		if (inject.firstChild) {
			document.body.appendChild(inject.firstChild);
		}
		// todo there are bugs above
		//inject.remove();

		if (newDialog) {
			//alert('DEBUG: InsertFetchedDialog: newDialog achieved');
			//alert(newDialog.length);

			newDialog = newDialog[0];

			//alert(newDialog);

			if (newDialog) {
				SetActiveDialog(newDialog);
				DraggingInit(0);
				ShowTimestamps();

			}
		}
		//window.location.replace(xmlhttp.responseURL);
//		document.open();
//		document.write(xmlhttp.responseText);
//		document.close();




*/


	}
} // InsertFetchedDialog()

function FetchDialog (dialogName) {
	var url = '/dialog/' + dialogName + '.html';

	if (document.getElementById) {
		var dialogExists = document.getElementById(dialogName);
		if (dialogExists) {
			if (GetPrefs('draggable')) {
				SetActiveDialog();
			}
			return false;
		}
	}

	return FetchDialogFromUrl(url);
} // FetchDialog()

function FetchDialogFromUrl (url) {
// InjectDialog () {
	if (window.XMLHttpRequest) {
		//alert('DEBUG: FetchDialog: window.XMLHttpRequest was true');

		var xmlhttp;
		if (window.xmlhttp2) {
			xmlhttp = window.xmlhttp2;
		} else {
			window.xmlhttp2 = new XMLHttpRequest();
			xmlhttp = window.xmlhttp2;
		}

		displayNotification('Meditate...');

        xmlhttp.onreadystatechange = window.InsertFetchedDialog;
        xmlhttp.open("GET", url, true);
		xmlhttp.setRequestHeader('Cache-Control', 'no-cache');
        xmlhttp.send();

        //alert('DEBUG: FetchDialog: finished xmlhttp.send()');

        return false;
	}
} // FetchDialogFromUrl()


//window.document.body.onfocus='document.title=this;';

/* / dragging.js */