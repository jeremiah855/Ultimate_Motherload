// Keep each layer's tile at its own slot depth, in column-major order.
// Each visible graphic still uses the game's exported sprite and transforms.
function umPlaceTerrainSlot(layer, name, slotDepth, art, worldX, worldY, angle, scale) {
    var clip = layer[name];
    if (art == "Empty" || art == "Blank" || art === 0 || art === "0") {
        if (clip != undefined) {
            clip.removeMovieClip();
        }
        return;
    }
    if (clip == undefined || clip.umTileArt !== art) {
        if (clip != undefined) {
            clip.removeMovieClip();
        }
        clip = layer.attachMovie("tile" + art, name, slotDepth);
        if (clip == undefined) {
            return;
        }
        clip.umTileArt = art;
    }
    if (clip._x != worldX) { clip._x = worldX; }
    if (clip._y != worldY) { clip._y = worldY; }
    // Compare the requested values, as Flash normalizes rotation and scale.
    if (clip.umAngle != angle) {
        clip._rotation = angle;
        clip.umAngle = angle;
    }
    if (clip.umScale != scale) {
        clip._xscale = scale;
        clip._yscale = scale;
        clip.umScale = scale;
    }
}
function umPaintTerrainSlot(slotX, slotY, actualX, actualY) {
    var name = "tile" + (slotX * 1000 + slotY);
    var slotDepth = 1 + slotX * 1000 + slotY;
    // The source assigns blank art and empty collision outside the map.
    // A scrolling slot can still contain an old tile, so clear both layers.
    if (actualX < 0 || actualX >= earthWidth || actualY < 0 || actualY >= earthHeight) {
        var oldGraphic = earthMC.e[name];
        if (oldGraphic != undefined) { oldGraphic.removeMovieClip(); }
        var oldLimit = earthMC.c[name];
        if (oldLimit != undefined) { oldLimit.removeMovieClip(); }
        return;
    }
    var graphic = getTileGraphicName(actualX, actualY);
    var cell = isEarthTileInBounds(actualX, actualY) ? earth[actualX][actualY][0] : undefined;
    var scale = computerZoomLevel == 3 && ((cell >= 1 && cell <= 24) || cell == 31) ? 102 : 100;
    umPlaceTerrainSlot(earthMC.e, name, slotDepth, graphic[0], actualX * 50, actualY * 50, graphic[1] * 90, scale);
    umPlaceTerrainSlot(earthMC.c, name, slotDepth, cell != undefined && cell != 0 && cell > -100 ? "Limit" : "Empty", actualX * 50, actualY * 50, 0, 100);
}
// Within a pass the camera maps neighboring slots to consecutive world tiles.
function umDisplayTerrain() {
    var firstX = computerZoomActualTileX(0);
    var firstY = computerZoomActualTileY(0);
    for (var x = 0; x < renderCols; x++) {
        for (var y = 0; y < renderRows; y++) {
            umPaintTerrainSlot(x, y, firstX + x, firstY + y);
        }
    }
    buildArtifactDetectorOverlay();
    drawAmazonitePathOverlay();
    drawExplosivesPathOverlay();
}
function umStreamRow(delta) {
    if (delta == 0) { return; }
    var firstX = computerZoomActualTileX(0);
    var worldY = computerZoomActualTileY(delta < 0 ? renderRows - 1 : 0);
    var slotY = delta < 0 ? oldTopRow : (oldTopRow + renderRows - 1) % renderRows;
    for (var x = 0; x < renderCols; x++) {
        umPaintTerrainSlot((x + oldLeftCol) % renderCols, slotY, firstX + x, worldY);
    }
}
function umStreamColumn(delta) {
    if (delta == 0) { return; }
    var worldX = computerZoomActualTileX(delta < 0 ? renderCols - 1 : 0);
    var firstY = computerZoomActualTileY(0);
    var slotX = delta < 0 ? oldLeftCol : (oldLeftCol + renderCols - 1) % renderCols;
    for (var y = 0; y < renderRows; y++) {
        umPaintTerrainSlot(slotX, (y + oldTopRow) % renderRows, worldX, firstY + y);
    }
}
updateEarthRow = umStreamRow;
updateEarthCol = umStreamColumn;
ultimatePaintTilePair = umPaintTerrainSlot;
displayEarth = umDisplayTerrain;

// Neighborhood mask in the same bit order as ultimateTileGraphicName.
ultimateTunnelGraphics = [
    ["Tunnel9",0], ["Tunnel8",0], ["Tunnel3",3], ["Tunnel3",3], ["Tunnel8",3], ["Tunnel6",2], ["Tunnel3",3], ["Tunnel3",3],
    ["Tunnel3",0], ["Tunnel3",0], ["Tunnel2",0], ["Tunnel2",0], ["Tunnel13",1], ["Tunnel13",1], ["Tunnel2",0], ["Tunnel2",0],
    ["Tunnel3",2], ["Tunnel12",3], ["Tunnel2",3], ["Tunnel2",3], ["Tunnel3",2], ["Tunnel12",3], ["Tunnel2",3], ["Tunnel2",3],
    ["Tunnel1",0], ["Tunnel1",0], ["Tunnel0",2], ["Tunnel0",2], ["Tunnel1",0], ["Tunnel1",0], ["Tunnel0",2], ["Tunnel0",2],
    ["Tunnel8",1], ["Tunnel6",3], ["Tunnel12",0], ["Tunnel12",0], ["Tunnel7",0], ["Tunnel5",3], ["Tunnel12",0], ["Tunnel12",0],
    ["Tunnel3",0], ["Tunnel3",0], ["Tunnel2",0], ["Tunnel2",0], ["Tunnel13",1], ["Tunnel13",1], ["Tunnel2",0], ["Tunnel2",0],
    ["Tunnel13",3], ["Tunnel11",2], ["Tunnel10",3], ["Tunnel10",3], ["Tunnel13",3], ["Tunnel11",2], ["Tunnel10",3], ["Tunnel10",3],
    ["Tunnel1",0], ["Tunnel1",0], ["Tunnel0",2], ["Tunnel0",2], ["Tunnel1",0], ["Tunnel1",0], ["Tunnel0",2], ["Tunnel0",2],
    ["Tunnel3",1], ["Tunnel13",2], ["Tunnel1",1], ["Tunnel1",1], ["Tunnel12",2], ["Tunnel11",1], ["Tunnel1",1], ["Tunnel1",1],
    ["Tunnel2",1], ["Tunnel2",1], ["Tunnel0",3], ["Tunnel0",3], ["Tunnel10",1], ["Tunnel10",1], ["Tunnel0",3], ["Tunnel0",3],
    ["Tunnel2",2], ["Tunnel10",2], ["Tunnel0",1], ["Tunnel0",1], ["Tunnel2",2], ["Tunnel10",2], ["Tunnel0",1], ["Tunnel0",1],
    ["Tunnel0",0], ["Tunnel0",0], ["Tunnel14",0], ["Tunnel14",0], ["Tunnel0",0], ["Tunnel0",0], ["Tunnel14",0], ["Tunnel14",0],
    ["Tunnel3",1], ["Tunnel13",2], ["Tunnel1",1], ["Tunnel1",1], ["Tunnel12",2], ["Tunnel11",1], ["Tunnel1",1], ["Tunnel1",1],
    ["Tunnel2",1], ["Tunnel2",1], ["Tunnel0",3], ["Tunnel0",3], ["Tunnel10",1], ["Tunnel10",1], ["Tunnel0",3], ["Tunnel0",3],
    ["Tunnel2",2], ["Tunnel10",2], ["Tunnel0",1], ["Tunnel0",1], ["Tunnel2",2], ["Tunnel10",2], ["Tunnel0",1], ["Tunnel0",1],
    ["Tunnel0",0], ["Tunnel0",0], ["Tunnel14",0], ["Tunnel14",0], ["Tunnel0",0], ["Tunnel0",0], ["Tunnel14",0], ["Tunnel14",0],
    ["Tunnel8",2], ["Tunnel7",1], ["Tunnel13",0], ["Tunnel13",0], ["Tunnel6",1], ["Tunnel5",2], ["Tunnel13",0], ["Tunnel13",0],
    ["Tunnel12",1], ["Tunnel12",1], ["Tunnel10",0], ["Tunnel10",0], ["Tunnel11",0], ["Tunnel11",0], ["Tunnel10",0], ["Tunnel10",0],
    ["Tunnel3",2], ["Tunnel12",3], ["Tunnel2",3], ["Tunnel2",3], ["Tunnel3",2], ["Tunnel12",3], ["Tunnel2",3], ["Tunnel2",3],
    ["Tunnel1",0], ["Tunnel1",0], ["Tunnel0",2], ["Tunnel0",2], ["Tunnel1",0], ["Tunnel1",0], ["Tunnel0",2], ["Tunnel0",2],
    ["Tunnel6",0], ["Tunnel5",0], ["Tunnel11",3], ["Tunnel11",3], ["Tunnel5",1], ["Tunnel4",0], ["Tunnel11",3], ["Tunnel11",3],
    ["Tunnel12",1], ["Tunnel12",1], ["Tunnel10",0], ["Tunnel10",0], ["Tunnel11",0], ["Tunnel11",0], ["Tunnel10",0], ["Tunnel10",0],
    ["Tunnel13",3], ["Tunnel11",2], ["Tunnel10",3], ["Tunnel10",3], ["Tunnel13",3], ["Tunnel11",2], ["Tunnel10",3], ["Tunnel10",3],
    ["Tunnel1",0], ["Tunnel1",0], ["Tunnel0",2], ["Tunnel0",2], ["Tunnel1",0], ["Tunnel1",0], ["Tunnel0",2], ["Tunnel0",2],
    ["Tunnel3",1], ["Tunnel13",2], ["Tunnel1",1], ["Tunnel1",1], ["Tunnel12",2], ["Tunnel11",1], ["Tunnel1",1], ["Tunnel1",1],
    ["Tunnel2",1], ["Tunnel2",1], ["Tunnel0",3], ["Tunnel0",3], ["Tunnel10",1], ["Tunnel10",1], ["Tunnel0",3], ["Tunnel0",3],
    ["Tunnel2",2], ["Tunnel10",2], ["Tunnel0",1], ["Tunnel0",1], ["Tunnel2",2], ["Tunnel10",2], ["Tunnel0",1], ["Tunnel0",1],
    ["Tunnel0",0], ["Tunnel0",0], ["Tunnel14",0], ["Tunnel14",0], ["Tunnel0",0], ["Tunnel0",0], ["Tunnel14",0], ["Tunnel14",0],
    ["Tunnel3",1], ["Tunnel13",2], ["Tunnel1",1], ["Tunnel1",1], ["Tunnel12",2], ["Tunnel11",1], ["Tunnel1",1], ["Tunnel1",1],
    ["Tunnel2",1], ["Tunnel2",1], ["Tunnel0",3], ["Tunnel0",3], ["Tunnel10",1], ["Tunnel10",1], ["Tunnel0",3], ["Tunnel0",3],
    ["Tunnel2",2], ["Tunnel10",2], ["Tunnel0",1], ["Tunnel0",1], ["Tunnel2",2], ["Tunnel10",2], ["Tunnel0",1], ["Tunnel0",1],
    ["Tunnel0",0], ["Tunnel0",0], ["Tunnel14",0], ["Tunnel14",0], ["Tunnel0",0], ["Tunnel0",0], ["Tunnel14",0], ["Tunnel14",0]
];
