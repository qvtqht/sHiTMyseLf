/* dragging.js */
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

window.draggingZ = 0;

function dragElement (elmnt, header) {
	var pos1 = 0, pos2 = 0, pos3 = 0, pos4 = 0;

	if (header) {
		// if present, the header is where you move the DIV from:
		header.onmousedown = 'dragMouseDown(this)';
	} else {
		// otherwise, move the DIV from anywhere inside the DIV:
		elmnt.onmousedown = 'dragMouseDown(this)';
	}

	var rect = elmnt.getBoundingClientRect();

	elmnt.style.position = 'absolute';
	elmnt.style.top = (rect.top) + "px";
	elmnt.style.left = (rect.left) + "px";

    //console.log(rect.top, rect.right, rect.bottom, rect.left);
	//elmnt.style.position = 'absolute';
	//elmnt.style.z-index = '9';
}

function dragMouseDown(elmnt) {
	e = window.event;

	e.preventDefault();

	// get the mouse cursor position at startup:
	pos3 = e.clientX;
	pos4 = e.clientY;

	document.onmouseup = 'closeDragElement(elmnt)';
	// call a function whenever the cursor moves:
	document.onmousemove = 'elementDrag(elmnt)';

	elmnt.style.zIndex = ++window.draggingZ;
}

function elementDrag(e) {
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

function closeDragElement(elmnt) {
	// stop moving when mouse button is released:
	document.onmouseup = '';
	document.onmousemove = '';

	if (elmnt) {
		SaveWindowState(elmnt);
		elmnt.style.zIndex = ++window.draggingZ;
		// keep incrementing the global zindex counter
	}
//
//		if (elmnt.id) {
//			if (window.SetPrefs) {
//				SetPrefs(elmnt.id + '.style.top', elmnt.style.top);
//				SetPrefs(elmnt.id + '.style.left', elmnt.style.left);
//			}
//		}
}

function SaveWindowState (elmnt) {
	var allTitlebar = elmnt.getElementsByClassName('titlebar');
	var firstTitlebar = allTitlebar[0];

	if (firstTitlebar && firstTitlebar.getElementsByTagName) {
		var elId = firstTitlebar.getElementsByTagName('b');
		if (elId && elId[0]) {
			elId = elId[0];

			if (elId && elId.innerHTML.length < 31) {
				SetPrefs(elId.innerHTML + '.style.top', elmnt.style.top);
				SetPrefs(elId.innerHTML + '.style.left', elmnt.style.left);
//				elements[i].style.top = GetPrefs(elId.innerHTML + '.style.top') || elId.style.top;
//				elements[i].style.left = GetPrefs(elId.innerHTML + '.style.left') || elId.style.left;
			} else {
				//alert('DEBUG: SaveWindowState: elId is false');
			}
		}
	}
}

function ArrangeAll () {
	//alert('DEBUG: DraggingInit: doPosition = ' + doPosition);
	var elements = document.getElementsByClassName('dialog');
	//for (var i = 0; i < elements.length; i++) {
	for (var i = elements.length - 1; 0 <= i; i--) { // walk backwards for positioning reasons
		elements[i].setAttribute('style', '');
//
//		var btnSkip = elements[i].getElementsByClassName('btnSkip');
//		if (btnSkip && btnSkip[0]) {
//			btnSkip[0].click();
//		}
	}
}

function DraggingInit (doPosition) {
// initializes all class=dialog elements on the page to be draggable
	if (!document.getElementsByClassName) {
		//alert('DEBUG: DraggingInit: sanity check failed, document.getElementsByClassName was FALSE');
		return '';
	}

	if (doPosition) {
		doPosition = 1;
	} else {
		doPosition = 0;
	}

	//alert('DEBUG: DraggingInit: doPosition = ' + doPosition);
	var elements = document.getElementsByClassName('dialog');
	//for (var i = 0; i < elements.length; i++) {
	for (var i = elements.length - 1; 0 <= i; i--) { // walk backwards for positioning reasons
		var allTitlebar = elements[i].getElementsByClassName('titlebar');
		var firstTitlebar = allTitlebar[0];

		if (firstTitlebar && firstTitlebar.getElementsByTagName) {
			dragElement(elements[i], firstTitlebar);
			var elId = firstTitlebar.getElementsByTagName('b');
			elId = elId[0];
			if (doPosition && elId && elId.innerHTML.length < 31) {
				elements[i].style.top = GetPrefs(elId.innerHTML + '.style.top') || elements[i].style.top;
				elements[i].style.left = GetPrefs(elId.innerHTML + '.style.left') || elements[i].style.left;
			} else {
				//alert('DEBUG: DraggingInit: elId is false');
			}
		}
	}

	return '';
} // DraggingInit()

/* / dragging.js */




=============================


//		if (elements[i].id && window.GetPrefs) {
//			var elTop = GetPrefs(elements[i].id + '.style.top');
//			var elLeft = GetPrefs(elements[i].id + '.style.left');
//
//			if (elTop && elLeft) {
//				elmnt.style.left = elLeft;
//				elmnt.style.top = elTop;
//			}
//
//			//var elTop = window.elementPosCounter || 1;
//			//var elTop = GetPrefs(elements[i].id + '.style.top');
//			//window.elementPosCounter += elmnt.style.height;
//
//			//var elLeft = GetPrefs(elements[i].id + '.style.left') || 1;
//
//			//if (elTop && elLeft) {
//				//elmnt.style.left = elLeft;
//				//elmnt.style.top = elTop;
//			//}
//		} else {
//			//alert('DEBUG: dragging.js: warning: id and/or GetPrefs() missing');
//		}
//		//dragElement(elements[i], firstTitlebar);





<div id='photos-preview'></div>
<input type="file" id="fileupload" multiple (change)="handleFileInput($event.target.files)" />
JS:

 function handleFileInput(fileList: FileList) {
        const preview = document.getElementById('photos-preview');
        Array.from(fileList).forEach((file: File) => {
            const reader = new FileReader();
            reader.onload = () => {
              var image = new Image();
              image.src = String(reader.result);
              preview.appendChild(image);
            }
            reader.readAsDataURL(file);
        });
    }




function previewImages() {

  var preview = document.querySelector('#preview');

  if (this.files) {
    [].forEach.call(this.files, readAndPreview);
  }

  function readAndPreview(file) {

    // Make sure `file.name` matches our extensions criteria
    if (!/\.(jpe?g|png|gif)$/i.test(file.name)) {
      return alert(file.name + " is not an image");
    } // else...

    var reader = new FileReader();

    reader.addEventListener("load", function() {
      var image = new Image();
      image.height = 100;
      image.title  = file.name;
      image.src    = this.result;
      preview.appendChild(image);
    });

    reader.readAsDataURL(file);

  }

}

document.querySelector('#file-input').addEventListener("change", previewImages);



<script type="text/javascript">function addEvent(b,a,c){if(b.addEventListener){b.addEventListener(a,c,false);return true}else return b.attachEvent?b.attachEvent("on"+a,c):false}
var cid,lid,sp,et,pint=6E4,pdk=1.2,pfl=20,mb=0,mdrn=1,fixhead=0,dmcss='//d217i264rvtnq0.cloudfront.net/styles/mefi/dark-mode20200421.2810.css';
















export default function potpack(boxes) {

    // calculate total box area and maximum box width
    let area = 0;
    let maxWidth = 0;

    for (const box of boxes) {
        area += box.w * box.h;
        maxWidth = Math.max(maxWidth, box.w);
    }

    // sort the boxes for insertion by height, descending
    boxes.sort((a, b) => b.h - a.h);

    // aim for a squarish resulting container,
    // slightly adjusted for sub-100% space utilization
    const startWidth = Math.max(Math.ceil(Math.sqrt(area / 0.95)), maxWidth);

    // start with a single empty space, unbounded at the bottom
    const spaces = [{x: 0, y: 0, w: startWidth, h: Infinity}];

    let width = 0;
    let height = 0;

    for (const box of boxes) {
        // look through spaces backwards so that we check smaller spaces first
        for (let i = spaces.length - 1; i >= 0; i--) {
            const space = spaces[i];

            // look for empty spaces that can accommodate the current box
            if (box.w > space.w || box.h > space.h) continue;

            // found the space; add the box to its top-left corner
            // |-------|-------|
            // |  box  |       |
            // |_______|       |
            // |         space |
            // |_______________|
            box.x = space.x;
            box.y = space.y;

            height = Math.max(height, box.y + box.h);
            width = Math.max(width, box.x + box.w);

            if (box.w === space.w && box.h === space.h) {
                // space matches the box exactly; remove it
                const last = spaces.pop();
                if (i < spaces.length) spaces[i] = last;

            } else if (box.h === space.h) {
                // space matches the box height; update it accordingly
                // |-------|---------------|
                // |  box  | updated space |
                // |_______|_______________|
                space.x += box.w;
                space.w -= box.w;

            } else if (box.w === space.w) {
                // space matches the box width; update it accordingly
                // |---------------|
                // |      box      |
                // |_______________|
                // | updated space |
                // |_______________|
                space.y += box.h;
                space.h -= box.h;

            } else {
                // otherwise the box splits the space into two spaces
                // |-------|-----------|
                // |  box  | new space |
                // |_______|___________|
                // | updated space     |
                // |___________________|
                spaces.push({
                    x: space.x + box.w,
                    y: space.y,
                    w: space.w - box.w,
                    h: box.h
                });
                space.y += box.h;
                space.h -= box.h;
            }
            break;
        }
    }

    return {
        w: width, // container width
        h: height, // container height
        fill: (area / (width * height)) || 0 // space utilization
    };
}
