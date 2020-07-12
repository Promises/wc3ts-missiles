import {MapPlayer, Timer, Unit, Trigger, Effect, Group} from "w3ts";


export interface MissileOptions {
    distance?: number;
    duration?: number;
    hitRadius?: number;
    collides?: boolean;
    heroOnly?: number;
    allies?: boolean;
    excludeUnit?: Unit;
    dmgFunc?: () => void;
    effectModel?: string;
    effectDmgModel?: string;
    height?: number;
    scale?: number;
    timerFunc?: () => void;
    attackType?: attacktype;
    damageType?: damagetype;
}

export class Missile {
    static MissileTimer = new Timer()    // global missile Timer.
    static MissileCadence = .03           // how fast the missile updates and checks for collision (higher = less accurate).
    static MissileStack: Missile[] = []            // where instances of missiles are stored.
    static Missile = {}            // initialize class table.
    private ownerUnit: Unit;
    private owner: MapPlayer;
    private landingX: number;
    private landingY: number;
    private missileX: number;
    private missileY: number;
    private missileZ: number;
    private traveled: number;
    private velocity: number;
    private angle: number;
    private effect: Effect;


    private effectModel: string = 'Abilities\\Weapons\\FireBallMissile\\FireBallMissile.mdl'
    private effectDmgModel: string = 'Abilities\\Weapons\\FireBallMissile\\FireBallMissile.mdl'
    private height: number = 60.0
    private scale: number = 1.0
    private duration: number = 1.5
    private distance: number = 600.0
    private damage: number = 100.0
    private hitRadius: number = 65.0
    private collides: boolean = false
    private heroOnly: boolean = false
    private allies: boolean = false
    private dmgFunc: (() => void) | undefined = undefined
    private timerFunc: (() => void) | undefined = undefined
    private excludeUnit: Unit | undefined = undefined
    private aType: attacktype = ATTACK_TYPE_NORMAL
    private dType: damagetype = DAMAGE_TYPE_NORMAL

    private searchGroup: Group = new Group();
    private damageGroup: Group = new Group();
    private filter: (u: Unit) => boolean;


    constructor(ownerUnit: Unit, landingX: number, landingY: number, options?: MissileOptions) {
        this.ownerUnit = ownerUnit;
        this.owner = ownerUnit.owner;
        this.landingX = landingX;
        this.landingY = landingY;

        this.missileX = ownerUnit.x
        this.missileY = ownerUnit.y
        this.missileZ = 0.0
        this.traveled = 0.0

        for (const key in options) {
            if (options.hasOwnProperty(key) && this.hasOwnProperty(key)) {
                this[key] = options[key];
            }
        }

        if (this.allies) {
            this.filter = (u: Unit) => this.filterAllies(u);
        } else {
            this.filter = (u: Unit) => this.filterEnemies(u);

        }

        this.velocity = this.distance / (this.duration / Missile.MissileCadence);
        this.angle = AngleBetweenPointsXY(this.missileX, this.missileY, landingX, landingY);
        if (!this.effect) {
            this.effect = new Effect(this.effectModel, this.missileX, this.missileY);
        }
    }

    private addToStack(): void {
        Missile.MissileStack.push(this);
        this.startTimer();
    }

    private startTimer(): void {
        if (Missile.MissileStack.length === 1 && Missile.MissileTimer.remaining === 0.0) {
            Missile.MissileTimer.start(Missile.MissileCadence, true, Missile.updateStack);
        }
    }

    static timerCheck(): void {
        if (Missile.MissileStack.length < 1) {
            Missile.MissileTimer.pause();
        }
    }

    static updateStack(): void {
        for (let missile of this.MissileStack) {
            if (missile.traveled > missile.distance) {
                missile.destroy()
            } else {
                missile.update();
            }
        }
    }

    private destroy(): void {
        this.effect.destroy();
        this.damageGroup.destroy();
        this.searchGroup.destroy();
        Missile.MissileStack = Missile.MissileStack.filter(value => value !== this);
        Missile.timerCheck();
    }

    private update(): void {
        this.traveled = this.traveled + this.velocity;
        [this.missileX, this.missileY] = PolarProjectionXY(this.missileX, this.missileY, this.velocity, this.angle);
        this.missileZ = GetTerrainCliffLevel(this.missileX, this.missileY) * 128 - 256 + this.height;
        this.effect.setYaw(this.angle * bj_DEGTORAD);
        this.effect.x = this.missileX;
        this.effect.y = this.missileY;
        this.effect.z = this.missileZ;
        if (this.timerFunc) {
            this.timerFunc();
        }
        this.collisionCheck();
    }

    private collisionCheck() {
        this.searchGroup.enumUnitsInRange(this.missileX, this.missileY, this.hitRadius, Condition(() => {
            let unit: Unit = Group.getFilterUnit();
            return unit && unit === this.excludeUnit;
        }))
        if (this.searchGroup.size > 0) {
            GroupUtilsAction(this.searchGroup, (unit: Unit) => {
                this.damageGroup.addUnit(unit);
                this.searchGroup.removeUnit(unit);
            })
        }
    }

    private filterAllies(u: Unit) {
        return u.isAlly(this.owner)
            && u.isAlive()
            && !u.isUnitType(UNIT_TYPE_STRUCTURE)
            && !u.inGroup(this.damageGroup);
    }

    private filterEnemies(u: Unit) {
        return u.isEnemy(this.owner)
            && u.isAlive()
            && !u.isUnitType(UNIT_TYPE_STRUCTURE)
            && !u.isUnitType(UNIT_TYPE_MAGIC_IMMUNE)
            && !u.inGroup(this.damageGroup);
    }
}


// :: get facing angle from A to B
// @x1,y1 = point A (facing from)
// @x2,y2 = point B (facing towards)
function AngleBetweenPointsXY(x1, y1, x2, y2): number {
    return bj_RADTODEG * Atan2(y2 - y1, x2 - x1)
}


// :: PolarProjectionBJ converted to x,y
// @x1,y1 = origin coord
// @d = distance between origin and direction
// @a = angle to project
function PolarProjectionXY(x1, y1, d, a): [number, number] {
    let x = x1 + d * Cos(a * bj_DEGTORAD)
    let y = y1 + d * Sin(a * bj_DEGTORAD)
    return [x, y]
}

function GroupUtilsAction(group: Group, callback: (unit: Unit) => void): void {
    let size = group.size;
    if (size > 0) {
        for (let i = 0; i < size; i++) {
            callback(group.getUnitAt(i));
        }
    }
}
