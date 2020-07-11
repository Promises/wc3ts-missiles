import { Players } from "w3ts/globals";
import { Unit, Item, MapPlayer, Timer, Handle, Point, Trigger, Effect, Rectangle, Group } from "w3ts";



const timerTimeout: number = 0.03125;
const playerNeutralPassive: MapPlayer = MapPlayer.fromIndex(PLAYER_NEUTRAL_PASSIVE);
const missileTimers: Map<Handle, Timer> = new Map(); //Map of our timers indexed by the Handle
const missiles: Map<Handle, Missile> = new Map(); //Map of our missiles
let fixedRotationAxes: boolean = false;


enum CollisionType {
    CIRCLE,
    RECTANGLE
}

abstract class Missile {
    private static readonly TIMER_TIMEOUT: number = timerTimeout;
    private static readonly NEUTRAL_PASSIVE: MapPlayer = playerNeutralPassive;
    private static readonly MAXIMUM_COLLISION_SIZE: number = 197.0;
    private static readonly COLLISION_ACCURACY_FACTOR: number = 1.0;
    private static readonly USE_COLLISION_Z_FILTER: boolean = true;
    private static readonly USE_DESTRUCTABLE_FILTER: boolean = true;
    private static readonly USE_item_FILTER: boolean = true;


    // GLOBALS l 472
    private CORE: Trigger = new Trigger();
    private MOVE: Trigger = new Trigger();
    private TMR: Timer = new Timer();
    private LOC: location = Location(0, 0);
    private RECT: Rectangle = new Rectangle(0, 0, 0, 0);
    private GROUP: Group = new Group();
    // For starting and stopping the timer.
    private active: number = 0
    // Arrays for data structure.
    private instances: number[];
    private missileList: Missile[];
    private expression: (() => boolean)[];
    private condition: boolexpr;
    private removed: number[];
    private destroying: boolean[];
    private recycling: boolean[];
    // Internal widget filter functions.
    private destFilter: boolexpr;
    private itemFilter: boolexpr;
    private UnitFilter: boolexpr;
    private table: ;


    source: Unit
    target: Unit
    distance: number
    owner: player
    speed: number
    acceleration: number
    damage: number
    turn: number
    data: number
    recycle: boolean
    wantDestroy: boolean
    collision: number
    collisionZ: number

    readonly allocated: boolean
    readonly id: number
    readonly dummy: Unit
    readonly origin: MissilePosition
    readonly impact: MissilePosition
    readonly terrainZ: number
    readonly x: number
    readonly y: number
    readonly z: number
    readonly angle: number


    private static GetUnitBodySize(u: Unit): number {
        return 100.0;
    }

    private static GetDestructableHeight(d: destructable): number {
        return GetDestructableOccluderHeight(d);
    }

    private static GetitemHeight(i: Item): number {
        return 16.0;
    }

    private static ToggleUnitIndex(enable: boolean): boolean {
        return true;
    }

    public GetLocZ(x: number, y: number) {
        MoveLocation(this.LOC, x, y)
        return GetLocationZ(this.LOC)
    }


}

class EulerAngles {
    private static XY_STEPS: number = 420
    private static Z_STEPS: number = 270
    private static angleTable: Map<number, number>[];
    private static xyDelta: number = (2.00 * Math.PI) / EulerAngles.XY_STEPS
    private static zDelta: number = (2.00 * Math.PI) / EulerAngles.Z_STEPS
    private static zSteps: number = 0
    static yaw: number = 0.00
    static pitch: number = 0.00
    static roll: number = 0.00

    static from(xyAngle: number, zAngle: number): void {
        xyAngle = xyAngle % 2.00 * Math.PI;
        zAngle = zAngle % 2.00 * Math.PI;
        let key = Math.floor(zAngle/this.zDelta) *this.XY_STEPS + Math.floor(xyAngle/this.xyDelta);
        EulerAngles.yaw = this.angleTable[0].get(key);
        EulerAngles.pitch = this.angleTable[1].get(key);
        EulerAngles.roll = this.angleTable[2].get(key);
    }

    static initAngles(key: number, dx: number, dy: number, dz: number): void {
        let N: number = dx*dx + dy*dy;
        let norm: number = N + dz*dz;
        
        if (norm === 0 ) {
            return;
        }
        norm = 1.00001 * Math.sqrt(norm);
        dx = dx/norm;
        dy = dy/norm;
        dz = dz/norm;
        if(N === 0 ) {
            this.angleTable[0].set(key, 0.00);
            this.angleTable[2].set(key, 0.00);

            if (dz > 0) {
                this.angleTable[1].set(key, -Math.PI*0.5)
            } else {
                this. angleTable[1].set(key, Math.PI*0.5)
            }

            return
        }
        N = Math.sqrt(N);
        let pitch;
        let cp;
        if( dy < 0 ) {
            pitch = Math.asin(dx*dz/N) + Math.PI;
            cp = Math.cos(pitch);
            if(fixedRotationAxes) {
                this.angleTable[0].set(key,Math.acos(dx/cp));
                this.angleTable[2].set(key,-Math.asin(dy*dz/(N*cp)) + Math.PI);
            } else {
                this.angleTable[2].set(key, Math.acos(dx/cp));
                this.angleTable[0].set(key, -Math.asin(dy*dz/(N*cp)) + Math.PI);
            }
        } else {
            pitch = -Math.asin(dx*dz/N);
            cp = Math.cos(pitch);
            if(fixedRotationAxes) {
                this.angleTable[0].set(key, Math.acos(dx/cp));
                this.angleTable[2].set(key, -Math.asin(dy*dz/(N*cp)));
            } else {
                this.angleTable[2].set(key, Math.acos(dx/cp));
                this.angleTable[0].set(key, -Math.asin(dy*dz/(N*cp)));
            }
        }
        this.angleTable[0].set(key, pitch);
    }


    static initOrientationTables(zStep: number): void {
        let xy = Math.cos(zStep*EulerAngles.zDelta);
        let z = Math.sin(zStep*EulerAngles.zDelta);
        let xySteps = 0;
        while (xySteps !== this.XY_STEPS) {
            this.initAngles(zStep*this.XY_STEPS + xySteps, xy*Math.cos(xySteps*this.xyDelta), xy*Math.sin(xySteps*this.xyDelta), z)
            xySteps++;
        }
    }

    static initTables(): void {
        this.initOrientationTables(this.zSteps);
        this.initOrientationTables(this.zSteps + this.Z_STEPS/2);
    }

    static onScopeInit() {
        this.angleTable = [];
        for (let i = 0; i < 3; i++) {
            this.initTables[i] = new Map<number,number>();
        }
        fixedRotationAxes = true;
        while (this.zSteps !== this.Z_STEPS/2) {
            this.initTables();
            this.zSteps++;
        }
    }
}

//Node from Missile.j
class MissileStack {
    static stack: Missile[] = [];
    
    public push(item: Missile) {
        MissileStack.stack.push(item);
    }

    public pop(): Missile {
        MissileStack.stack.reverse;
        let item = MissileStack.stack.pop();
        MissileStack.stack.reverse;
        return item;
    }
}

class MissileEffects {
    effectHandle: Handle;
    missile: Missile;
    //lookupTable[0].get(key)
    //lookupTable[0].set(key, value)
    //lookupTable[0].has(key)
    
    handle(): EffectHandle {
        return ;
    }

    getMissile(): Missile {
        return this.missile;
    }
}

