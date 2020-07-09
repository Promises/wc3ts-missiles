enum CollisionType {
    CIRCLE,
    RECTANGLE
}


abstract class Missile {
    private static readonly TIMER_TIMEOUT: number = 1.0 / 32.0;
    private static readonly NEUTRAL_PASSIVE: player = Player(PLAYER_NEUTRAL_PASSIVE);
    private static readonly MAXIMUM_COLLISION_SIZE: number = 197.0;
    private static readonly COLLISION_ACCURACY_FACTOR: number = 1.0;
    private static readonly USE_COLLISION_Z_FILTER: boolean = true;
    private static readonly USE_DESTRUCTABLE_FILTER: boolean = true;
    private static readonly USE_ITEM_FILTER: boolean = true;


    // GLOBALS l 472
    private CORE: trigger = CreateTrigger()
    private MOVE: trigger = CreateTrigger()
    private TMR: timer = CreateTimer()
    private LOC: location = Location(0., 0.)
    private RECT: rect = Rect(0., 0., 0., 0.)
    private GROUP: group = CreateGroup()
    // For starting and stopping the timer.
    private active: number = 0
    // Arrays for data structure.
    private instances: number[];
    private missileList: Missile[];
    private expression: (() => boolean)[];
    private condition: triggercondition[];
    private removed: number[];
    private destroying: boolean[];
    private recycling: boolean[];
    // Internal widget filter functions.
    private destFilter: boolexpr;
    private itemFilter: boolexpr;
    private unitFilter: boolexpr;
    private table: TableArray;
    private fixedRotationAxes: boolean;


    source: unit
    target: unit
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
    readonly dummy: unit
    readonly origin: MissilePosition
    readonly impact: MissilePosition
    readonly terrainZ: number
    readonly x: number
    readonly y: number
    readonly z: number
    readonly angle: number


    private static GetUnitBodySize(u: unit): number {
        return 100.0;
    }

    private static GetDestructableHeight(d: destructable): number {
        return GetDestructableOccluderHeight(d);
    }

    private static GetItemHeight(i: item): number {
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

class EulerAngles extends Array {
    private static XY_STEPS: number = 420
    private static Z_STEPS: number = 270
    private static angleTable: TableArray;
    private static xyDelta: number = (2.00 * bj_PI) / EulerAngles.XY_STEPS
    private static zDelta: number = (2.00 * bj_PI) / EulerAngles.Z_STEPS
    private static zSteps: number = 0
    static readonly yaw: number = 0.00
    static readonly pitch: number = 0.00
    static readonly roll: number = 0.00

    static from(xyAngle: number, zAngle: number): void {
        xyAngle = xyAngle % 2.00 * Math.PI;
        zAngle = zAngle % 2.00 * Math.PI;
        let key = R2I(zAngle/this.zDelta) *this.XY_STEPS + R2I(xyAngle/this.xyDelta);
        yaw = this.angleTable[0].real[key];
        pitch = this.angleTable[1].real[key];
        roll = this.angleTable[2].real[key];
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
        if(N=== 0 ) {
            angleTable[0].real[key] = 0.00
            angleTable[2].real[key] = 0.00

            if (dz > 0) {
                angleTable[1].real[key] = -bj_PI*0.5
            } else {
                angleTable[1].real[key] = bj_PI*0.5
            }

            return
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

class EffectHandle {
    effect: effect;

    static onRemove(item: EffectHandle): void {
        DestroyEffect(item.effect);
    }

    static allocate(): void {
        return 
    }
}

class Effect {
    effectHandle: EffectHandle;
    missile: Missile;
    //lookupTable[0].get(key)
    //lookupTable[0].set(key, value)
    //lookupTable[0].has(key)
    
    handle(): EffectHandle {
        return this.effectHandle;
    }

    getMissile(): Missile {
        return this.missile;
    }


}