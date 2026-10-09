import QtQuick
import Quickshell

// Headless contract test for the same rectangle collision and packing rules used by GridLayoutModel.
ShellRoot {
    function overlaps(a,b) { return a.x < b.x+b.w && b.x < a.x+a.w && a.y < b.y+b.h && b.y < a.y+a.h }
    function canPlace(list,item,cols) {
        if (item.x<0 || item.y<0 || item.x+item.w>cols) return false
        return !list.some(other=>other.id!==item.id&&overlaps(other,item))
    }
    function tidy(items,cols) {
        const placed=[]
        for (const item of items.slice().sort((a,b)=>a.y-b.y||a.x-b.x)) {
            let spot=null
            for(let y=0;y<64&&!spot;y++) for(let x=0;x+item.w<=cols;x++)
                if(canPlace(placed,{id:"probe",x:x,y:y,w:item.w,h:item.h},cols)){spot={x:x,y:y};break}
            if(!spot) throw new Error("no placement")
            placed.push(Object.assign({},item,spot))
        }
        return placed
    }
    Component.onCompleted: {
        const a={id:"a",x:0,y:0,w:2,h:1}, b={id:"b",x:2,y:0,w:2,h:1}
        if (!canPlace([a,b],a,7) || canPlace([a,b],{id:"c",x:1,y:0,w:2,h:1},7)) throw new Error("placement/collision failure")
        const packed=tidy([b,a],7)
        if (packed.length!==2 || packed[0].x!==0 || packed[1].x!==2) throw new Error("tidy failure")
        console.log("grid-test: placement, collision, tidy passed")
        Qt.quit()
    }
}
