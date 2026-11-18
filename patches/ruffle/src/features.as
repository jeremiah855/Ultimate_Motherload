var ucStorage = SharedObject.getLocal("UltimateMotherloadCheckpoint1","/");
var ucPrefs = SharedObject.getLocal("UltimateMotherloadCamera1","/");
var savedCamera = ucPrefs.data.zoom;
_global.computerZoomPreferredLevel = typeof(savedCamera) == "number" && savedCamera >= 0 && savedCamera <= 3 ? savedCamera : 0;

function ucButton(parent, name, depth, x, width, caption, action) {
    var b = parent.createEmptyMovieClip(name,depth);
    b._x = x;
    b.lineStyle(1,6719623,100);
    b.beginFill(1053462,100);
    b.moveTo(0,0); b.lineTo(width,0); b.lineTo(width,22); b.lineTo(0,22); b.lineTo(0,0);
    b.endFill();
    b.createTextField("label",1,1,2,width-2,19);
    var f = new TextFormat("_sans",11,16777215,true);
    f.align = "center";
    b.label.selectable = false;
    b.label.setNewTextFormat(f);
    b.label.text = caption;
    b.onRelease = action;
    return b;
}
function ucCameraText(level) {
    return ["Camera: Classic", "Camera: 1.5x", "Camera: 2x", "Camera: Full width"][level];
}
computerZoomFactor = function() {
    if (computerZoomLevel == 1) { return 1.5; }
    if (computerZoomLevel == 2) { return 2; }
    if (computerZoomLevel == 3) { return Math.max(1,earthWidth*50/gameViewBaseW); }
    return 1;
};
computerZoomName = function() {
    return ["Classic", "1.5x", "2x", "Full width"][computerZoomLevel];
};
computerZoomExtraSideCols = function() {
    if (computerZoomLevel == 1) { return 5; }
    if (computerZoomLevel == 2) { return 8; }
    return 0;
};
var ucNativeChangeZoom = changeComputerZoom;
changeComputerZoom = function(delta) {
    ucNativeChangeZoom(delta);
    ucPrefs.data.zoom = computerZoomLevel;
    ucPrefs.flush();
};
function ucToggleCamera() {
    var title = _root._currentframe == 2;
    if ((title && !menuActive) || (!title && quitConfirmationMC._visible)) { return; }
    var level = title ? _global.computerZoomPreferredLevel : computerZoomLevel;
    if (!title && ucCameraPending != undefined) { level = ucCameraPending; }
    level = (level + 1) % 4;
    if (!title) { ucCameraPending = level; }
    _global.computerZoomPreferredLevel = level;
    ucPrefs.data.zoom = level;
    ucPrefs.flush();
    ucToolbar.zoom.label.text = ucCameraText(level);
}
function ucApplyCamera() {
    if (ucCameraPending == undefined) { return; }
    restoreComputerZoomModalWorldClips();
    computerZoomLevel = ucCameraPending;
    delete _root.ucCameraPending;
    if (computerZoomLevel == 0) { resetComputerZoomView(); }
}
// One character per terrain cell: tile number plus its rotation.
// Preserve a transient or absent value explicitly; refuse out-of-range input.
function ucPackMap(grid,w,h) {
    var columns = [];
    for (var x=0; x<w; x++) {
        var chars = [];
        for (var y=0; y<h; y++) {
            var cell = grid[x][y];
            if (cell == undefined) { return undefined; }
            var kind = cell[0] == undefined ? 512 : cell[0];
            var rot = cell[1] == undefined ? 7 : cell[1];
            if (kind == -100 || kind < -1024 || kind > 512 || kind != int(kind) || rot < 0 || rot > 7 || rot != int(rot)) { return undefined; }
            chars.push(String.fromCharCode(32 + (kind + 1024)*8 + rot));
        }
        columns.push(chars.join(""));
    }
    return columns;
}
function ucUnpackMap(columns,grid,w,h) {
    for (var x=0; x<w; x++) {
        for (var y=0; y<h; y++) {
            var v = columns[x].charCodeAt(y)-32;
            var k = int(v/8)-1024;
            var r = v%8;
            grid[x][y][0] = k == 512 ? undefined : k;
            grid[x][y][1] = r == 7 ? undefined : r;
        }
    }
}
function ucValid(s) {
    if (s == undefined || s.version != 1 || s.stats.length != 34 || s.columns.length != 36 || !isFinite(s.seed)) { return false; }
    for (var i=0;i<36;i++) {
        if (typeof(s.columns[i]) != "string" || s.columns[i].length != 600) { return false; }
    }
    for (i=0;i<34;i++) { if (typeof(s.stats[i]) != "number" || !isFinite(s.stats[i])) { return false; } }
    return true;
}
function ucNotify(message) {
    if (_root._currentframe == 20) { saveText.text = message; }
    if (ucToolbar.note != undefined) { ucToolbar.note.text = message; }
}
function ucFinishWrite(ok) {
    if (!ok) {
        if (ucPrior == undefined) { delete ucStorage.data.slot; }
        else { ucStorage.data.slot = ucPrior; }
    }
    delete _root.ucPrior;
    ucWriting = false;
    ucNotify(ok ? "Checkpoint saved." : "Save failed. Check local storage.");
    if (ok && ucQuitAfterSave && _root._currentframe == 18) { _root.gotoAndStop(2); }
    ucQuitAfterSave = false;
}
function ucSave(quitAfter) {
    if (ucWriting) { return; }
    if (battleMode || atv.mod == "dead" || !droppedOff) { ucNotify("Save after landing, outside a boss fight."); return; }
    var columns = ucPackMap(earth,earthWidth,earthHeight);
    if (columns == undefined) { ucNotify("Finish digging and try again."); return; }
    var a = [p1.score,p1.cash,p1.scoreBillion,lvl,atv.hp,Math.max(1,int(atv.fuel)),atv.hull,atv.drill,atv.engine,atv.fuelTank,atv.radiator,atv.bay];
    for (var i=0;i<10;i++) { a.push(Number(atv.bayContents[i])); }
    for (i=0;i<9;i++) { a.push(atv.usableItem[i] == undefined ? 0 : Number(atv.usableItem[i])); }
    a.push(lastTransmission,playTime,totalPlayTime);
    var s = {version:1, columns:columns, stats:a, seed:iRngSeed, rng:rngSeed, mode:currentGameBehavior, newItems:optNewItems, deepest:maxDepth, day:dayTime, cheating:cheating};
    if (!ucValid(s)) { ucNotify("Checkpoint data incomplete. Try again."); return; }
    ucPrior = ucStorage.data.slot;
    ucWriting = true;
    ucQuitAfterSave = quitAfter;
    ucStorage.data.slot = s;
    ucStorage.onStatus = function(info) {
        if (_root.ucWriting) { _root.ucFinishWrite(info.code == "SharedObject.Flush.Success"); }
    };
    var status = ucStorage.flush();
    if (status == "pending") { ucNotify("Waiting for storage permission."); }
    else { ucFinishWrite(status === true); }
}
function ucResume() {
    if (!menuActive || ucWriting) { return; }
    var s = ucStorage.data.slot;
    if (!ucValid(s)) { ucNotify("No usable checkpoint."); return; }
    ucLoading = s;
    loadGameArray = s.stats;
    loadGameFlag = true;
    loadedGame = false;
    currentGameBehavior = s.mode;
    optNewItems = s.newItems;
    playerSeed = s.seed;
    playerSetSeed = true;
    removeNewItemsToggleButton();
    removeEarthquakeToggleButton();
    runningTimer.reset(); runningTimer.start();
    _root.gotoAndPlay(4);
}
var ucGenerate = seededGenerateEarth;
seededGenerateEarth = function() {
    ucGenerate();
    if (ucLoading != undefined) {
        ucUnpackMap(ucLoading.columns,earth,earthWidth,earthHeight);
        maxDepth = ucLoading.deepest; dayTime = ucLoading.day;
        rngSeed = ucLoading.rng; cheating = ucLoading.cheating;
        delete _root.ucLoading;
    }
};
displaySavePod = function() {
    if (earthMC.savePodMC == undefined) {
        var pod = earthMC.attachMovie("savePodMC","savePodMC",919004);
        pod._x = 850; pod._y = -50;
    }
    savePodDisplayed = true;
};
function ucMenu(title) {
    var t = _root.createEmptyMovieClip("ucToolbar",912430);
    t._x=5; t._y=3;
    ucButton(t,"zoom",1,0,132,ucCameraText(title ? _global.computerZoomPreferredLevel : computerZoomLevel),ucToggleCamera);
    t.createTextField("note",3,2,25,285,20);
    t.note.selectable=false;
    t.note.textColor=16777215;
}
// Called by the existing Continue button. False falls through to its
// original next-level behavior, including its original eligibility checks.
function ucContinue() {
    if (!menuActive || ucEarnedContinuation || !ucValid(ucStorage.data.slot)) { return false; }
    ucResume();
    return true;
}
