// TO DO - CONVERT THIS TO TYPESCRIPT
library Missile /* version 3.0.2 (Unofficial Update for patches 1.30+)
Unofficial updates link: https://www.hiveworkshop.com/threads/missile.265370/page-13#post-3429957
*************************************************************************************
*
*   Creating custom projectiles in Warcraft III.
*
*   Major goal:
*       No unessary external requirements.
*       Implements code optional.
*
*   Philosophy:
*       I want that feature --> Compiler writes that code into your map script.
*       I don't want that   --> Compiler ignores that code completely.
*
*   Important:
*       Take yourself 2 minutes time to setup Missile correctly.
*       Otherwise I can't guarantee, that Missile works the way you want.
*       Once the setup is done, you can check out some examples and Missile will be easy
*       to use for everyone. I promise it.
*
*       Do the setup at:
*
*           1.) Import instruction
*           2.) Global configuration
*           3.) Function configuration    
*
*   Credits to Dirac, emjlr3, AceHart, Bribe, Wietlol,
*              Nestharus, Maghteridon96, Vexorian and Zwiebelchen.
*
*************************************************************************************
*
*   */ requires /*
*
*       */ Table                    /*  https://www.hiveworkshop.com/threads/188084/
*
*       */ LinkedList               /*  https://www.hiveworkshop.com/threads/325635/
*           - Make the vJass code shorter and more readable
*
*************************************************************************************
*
*   Optional requirements listed can reduce overall code generation,
*   add safety mechanisms, decrease overhead and optimize handle management.
*   For a better overview I put them into blocks.
*
*   I recommend to use at least one per block in your map.
*
*   a) For best debug results: ( Useful )
*       */ optional ErrorMessage    /*  https://github.com/nestharus/JASS/blob/master/jass/Systems/ErrorMessage/main.j
*
*   b) Fatal error protection: ( Case: unit out moves of world bounds )
*           - WorldBounds is safer than BoundSentinel.
*           - WorldBounds adds more overhead than BoundSentinel.
*           - Using none of these two forces Missile to switch from SetUnitX/Y to the SetUnitPosition native.
*       */ optional WorldBounds     /*  https://github.com/nestharus/JASS/blob/master/jass/Systems/WorldBounds/script.j
*       */ optional BoundSentinel   /*  wc3c.net/showthread.php?t=102576
*
*   c) Unit indexing: ( Avoid an onIndex event )
*           - not required for Missile. Only if you use one already.
*       */ optional UnitIndexer     /*  github.com/nestharus/JASS/tree/master/jass/Systems/Unit%20Indexer
*
*   d) Allocator:
*           - Reduces generated codes and variables
*           - Takes advantage of the new JASS_MAX_ARRAY_SIZE value for patches 1.29+
*       */ optional Alloc           /*  https://www.hiveworkshop.com/threads/324937/
*
*   e) Game version detection:
*           - Helps fix bugs introduced in 1.30.x related to new SFX natives
*       */ optional GameVersion     /*  https://www.hiveworkshop.com/threads/308204/
*
************************************************************************************
*
*   1. Import instruction
*   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
*       • Copy Missile into to your map.
*       • You need a dummy unit, using Vexorians "dummy.mdx".
*         This unit must use the locust and crow form ability. ( Aloc & Amrf )
*                   ¯¯¯¯
*
*   2. Global configuration
*   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
*       Seven constants to setup!
*/
    globals

        /**
        *   Missiles are moved periodically. An interval of 1./32. is recommended.
        *       • Too short timeout intervals may cause performance issues.
        *       • Too large timeout intervals may look fishy.
        */
        public constant real TIMER_TIMEOUT                          = 1./32.

        /**
        *   Owner of all Missile dummies. Should be a neutral player in your map.
        *
        *   (Depreciated in version 3.0.0)
        */
        public constant player NEUTRAL_PASSIVE                      = Player(PLAYER_NEUTRAL_PASSIVE)

        /**
        *   Raw code of the dummy unit. Object Editor ( F6 )
        *       • Must be correct, otherwise missile dummies can neither be recycled nor destroyed.
        *       • Units of other type ids will not be thrown into the recycler bin.
        *
        *   (Depreciated in version 3.0.0)
        */
        public constant integer DUMMY_UNIT_ID                       = 'dumi'

        /**
        *   The maximum collision size used in your map. If unsure use 197. ( Town hall collision )
        *       • Applies for all types of widgets.
        *       • A precise value can improve Missile's performance,
        *         since smaller values enumerate less widgtes per loop per missile.
        */
        public constant real MAXIMUM_COLLISION_SIZE                 = 197.

        /**
        *   Collision types for missiles. ( Documentation only )
        *   Missile decides internally each loop which type of collision is required.
        *       • Uses circular collision dectection for speed < collision. ( Good accuracy, best performance )
        *       • Uses rectangle collision for speed >= collision. ( Best accuracy, normal performance )
        */
        public constant integer COLLISION_TYPE_CIRCLE               = 0
        public constant integer COLLISION_TYPE_RECTANGLE            = 1

        /**
        *   Determine when rectangle collision is required to detect nearby widgets.
        *       • The smaller the factor the earlier rectangle collision is used. ( by default 1. )
        *       • Formula: speed >= collision*Missile_COLLISION_ACCURACY_FACTOR
        */
        public constant real    COLLISION_ACCURACY_FACTOR           = 1.

// Optional toogles:
// ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
//      Set booleans listed below to "true" and the compiler will write
//      the feature into your map. Otherwise this code is completly ignored.                                      
//          • Yay, I want that           --> "true"
//          • Naah that's useless for me --> "false"

        /**
        *   USE_COLLISION_Z_FILTER enables z axis checks for widget collision. ( Adds minimal overhead )
        *   Use it when you need:
        *       • Missiles flying over or under widgets.
        *       • Determine between flying and walking units.
        */
        public constant boolean USE_COLLISION_Z_FILTER              = true

        /**
        *   WRITE_DELAYED_MISSILE_RECYCLING enables a delayed dummy recycling system. ( Very recommended )
        *   Use it if:
        *       • You use a dummy recycling library like MissileRecycler, Dummy or xedummy.
        *       • You want to properly display death animations of effects added to missiles.
        *
        *   (Depreciated in version 3.0.0)
        */
        public constant boolean WRITE_DELAYED_MISSILE_RECYCLING     = true

        /**
        *   DELAYED_MISSILE_DEATH_ANIMATION_TIME is the delay in seconds
        *   Missile holds back a dummy, before recycling it.
        *       • The time value does not have to be precise.
        *       • Requires WRITE_DELAYED_MISSILE_RECYCLING = true
        *
        *   (Depreciated in version 3.0.0)
        */
        private constant real DELAYED_MISSILE_DEATH_ANIMATION_TIME  = 2.

        /**
        *   USE_DESTRUCTABLE_FILTER and USE_ITEM_FILTER are redundant constants from previous Missile versions.
        *   They do nothing, but remain for backwards compatibilty.
        *   From Missile version 1.5 on all widget collisions are always enabled.
        */
        public constant boolean USE_DESTRUCTABLE_FILTER             = true
        public constant boolean USE_ITEM_FILTER                     = true
    endglobals
/*  
*  3. Function configuration
*  ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
*       Four functions to setup!
*/
    /**
    *   GetUnitBodySize(unit) returns a fictional value for z - axis collision.
    *   You have two options:
    *       • One constant value shared over all units.
    *       • Dynamic values based on handle id, type id, unit user data, scaling or other parameters.
    */
    function GetUnitBodySize takes unit whichUnit returns real
        return 100.// Other example: return LoadReal(hash, GetHandleId(whichUnit), KEY_UNIT_BODY_SIZE)
    endfunction

    /**
    *   Same as GetUnitBodySize, but for destructables.
    *   Using occluder height is an idea of mine. Of course you can use your own values.
    */
    function GetDestructableHeight takes destructable d returns real
        return GetDestructableOccluderHeight(d)// Other example: return 100.
    endfunction

    /**
    *   Same as GetUnitBodySize, but for items.
    *   Again it's up to you to figure out a fictional item height.
    */
    function GetItemHeight takes item i returns real
        return 16.
    endfunction
   
    /**
    *   Unit indexers and missiles ( Only if you don't use a dummy recycling library )
    *   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    *   It is most likely intended that projectiles don't run through a unit indexing process.
    *   ToogleUnitIndexer runs:
    *       • Directly before a dummy is created.
    *       • Directly after dummy unit creation.
    *
    *   Please return the previous setup of your indexing tool ( enabled, disabled ),
    *   so Missile can properly reset it to the original state.
    */
    private function ToogleUnitIndexer takes boolean enable returns boolean
        local boolean prev = true//UnitIndexer.enabled
        // set UnitIndexer.enabled = enable
        return prev
    endfunction

/**
*   4. API
*   ¯¯¯¯¯¯
*/
//! novjass ( Disables the compiler until the next endnovjass )

        // Custom type Missile for your projectile needs.
        struct Missile extends array

        // Constants:
        // ==========
            //
            readonly static constant string ORIGIN = "origin"
            //  • Attach point name for fxs on dummies.

            readonly static constant real   HIT_BOX = (2./3.)
            //  • Fictional hit box for homing missiles.
            //    while 0 would be the toe and 1 the head of a unit.

        // Available creators:
        // ===================
            //
            static method createEx takes unit missileDummy, real impactX, real impactY, real impactZ returns Missile
            //  • Core creator method.
            //  • May launches any unit.
            //  • Units of type Missile_DUMMY_UNIT_ID get recycled in the end.

            static method create takes real x, real y, real z, real angleInRadians, real distanceToTravel, real endZ returns Missile
            //  • Converts arguments to fit into createEx, then calls createEx.

            static method createXYZ takes real x, real y, real z, real impactX, real impactY, real impactZ returns Missile
            //  • Converts arguments to fit into createEx, then calls createEx.

        // Available destructors:
        // ======================
            //
            return true
            //  • Core destructor.
            //  • Returning true in any of the interface methods of the MissileStruct module
            //    will destroy that instance instantly.

            method destroy   takes nothing returns nothing
            //  • Destroys the missile during the next timer callback.

            method terminate takes nothing returns nothing
            //  • Destroys the missile instantly.

        // Fields you can set and read directly:
        // =====================================
            //
            unit       source
            unit       target      // For homing missiles.
            real       distance    // Distance traveled.
            player     owner       // Pseudo owner for faster onCollide evaluation. The proper dummy owner remains PLAYER_NEUTRAL_PASSIVE.
            real       speed       // Vector lenght for missile movement in plane x / y. ( DOES NOT TAKE THE TIMER TIMEOUT IN ACCOUNT )
            real       acceleration
            real       damage
            real       turn        // Set a turn rate for missiles.
            integer    data        // For data transfer set and read data.
            boolean    recycle     // Is automatically set to true, when a Missile reaches it's destination.
            boolean    wantDestroy // Set wantDestroy to true, to destroy a missile during the next timer callback.

            // Neither collision nor collisionZ accept values below zero.
            real       collision   // Collision size in plane x / y.
            real       collisionZ  // Collision size in z - axis. ( deprecated )

        // Fields you can only read:
        // =========================    
            //
            readonly boolean         allocated      
            readonly unit            dummy// The dummy unit of this missile.

            // Position members for you needs.
            readonly MissilePosition origin// Grants access to readonly members of MissilePosition,
            readonly MissilePosition impact// which are "x", "y", "z", "angle", "distance", "slope" and the pitch angle "alpha".
                                           // Furthermore method origin.move(x, y, z) and impact.move(x, y, z).
            readonly real            terrainZ
            readonly real            x
            readonly real            y
            readonly real            z
            readonly real            angle// Current angle in radians.

        // Method operators for set and read:
        // ==================================
            //
            method operator model= takes string modelFile returns nothing
            method operator model  takes nothing returns string
            //  • Adds an effect handle on a missile dummy to it's "origin".
            //  • You can read the file path.
            //  • For multiple effects access "this.dummy" in your struct.

            method operator scale= takes real value returns nothing
            method operator scale  takes nothing returns real
            //  • Set and read the scaling of the dummy unit.

            method operator curve= takes real value returns nothing
            method operator curve  takes nothing returns real
            //  • Enables curved movement for your missile. ( Pass in radians, NOT degrees )
            //  • Do not pass in PI/2.

            method operator arc=   takes real value returns nothing
            method operator arc    takes nothing returns real
            //  • Enables arcing movement for your missile. ( Pass in radians, NOT degrees )
            //  • Do not pass in PI/2.

        // Methods for missile movement:
        // =============================
            //
            method bounce           takes nothing returns nothing
            //  • Moves the MissilePosition "origin" to the current missile coordinates.
            //  • Resets the distance traveled to 0.

            method deflect          takes real tx, real ty returns nothing
            //  • Deflect the missile towards tx, ty. Then calls bounce.      

            method deflectEx        takes real tx, real ty, real tz returns nothing
            //  • Deflect the missile towards tx, ty, tz. Then calls bounce.

            method flightTime2Speed takes real duration returns nothing
            //  • Converts a fly time to a vector lenght for member "speed".
            //  • Does not take acceleration into account. ( Disclaimer )

            method setMovementSpeed takes real value returns nothing
            //  • Converts Warcraft III movement speed to a vector lenght for member "speed".

        // Methods for missile collision: ( all are hashtable entries )
        // ==============================
            // By default a widget can only be hit once per missile.
            //
            method hitWidget        takes widget w returns nothing
            //  • Saves a widget in the memory as hit by this instance.

            method hasHitWidget     takes widget w returns boolean
            //  • Returns true, if "w" has been hit by this instance.

            method removeHitWidget  takes widget w returns nothing
            //  • Removes a widget from this missile's memory for widget collision. ( Can hit "w" again )

            method flushHitWidgets  takes nothing returns nothing
            //  • Flushes a missile's memory for widget collision. ( All widgets can be hit again )

            method enableHitAfter   takes widget w, real seconds returns nothing
            //  • Automatically calls removeHitWidget(w) after "seconds" time. ( Can hit "w" again after given time )

        // UPDATE 3.0.0 ADDITIONAL FEATURES:
        // ============================

            method effect.addModel      takes string model  returns effect
            method effect.removeModel   takes string model  returns nothing
            method effect.clearModels   takes nothing       returns nothing
            //  • Adds/removes/clears Missile sfx models

            method effect.getHandle     takes string model  returns effect
            //  • For Missiles with multiple sfx models, allows you to access those individual <effect> handles
            //  • Useful for example if one wants some <effect> to have a certain offset from the Missile's origin

        // Module MissileStruct:
        // =====================
            //
            module MissileLaunch // ( optional )
            module MissileStruct
            //  • Enables the entire missile interface for that struct.

        // Interface in structs: ( Must implement module MissileStruct )
        // =====================
            //
            //  • Write one, many or all of the static method below into your struct.
            //  • Missiles launched in this struct will run those methods, when their events fire.
            //
            //  • All of those static methods must return a boolean.
            //      a) return true  --> destroys the missile instance instantly.
            //      b) return false --> keep on flying.

        // Available static method:
        // ========================
            //
            static method onCollide            takes Missile missile, unit hit returns boolean
            //  • Runs for units in collision range of a missile.

            static method onDestructable       takes Missile missile, destructable hit returns boolean
            //  • Runs for destructables in collision range of a missile.

            static method onItem               takes Missile missile, item hit returns boolean
            //  • Runs for items in collision range of a missile.

            static method onTerrain takes Missile missile returns boolean
            //  • Runs when a missile collides with the terrain. ( Ground and cliffs )

            static method onFinish  takes Missile missile returns boolean
            //  • Runs only when a missile reaches it's destination.
            //  • However does not run, if a Missile is destroyed in another method.

            static method onPeriod  takes Missile missile returns boolean
            //  • Runs every Missile_TIMER_TIMEOUT seconds.

            static method onRemove takes Missile missile returns boolean
            //  • Runs when a missile is destroyed.
            //  • Unlike onFinish, onRemove will runs ALWAYS when a missile is destroyed!!!
            //
            //  For onRemove the returned boolean has a unique meaning:
            //  • Return true will recycle this missile delayed. ( Only if WRITE_DELAYED_MISSILE_RECYCLING = true )
            //  • Return false will recycle this missile right away.

            static method launch takes Missile toLaunch returns nothing
            //  • Well ... Launches this Missile.
            //  • Missile "toLaunch" will behave as declared in the struct. ( static methods from above )

    // Misc: ( From the global setup )
    // =====
        //
        // Constants:
        // ==========
            //
            public constant real    TIMER_TIMEOUT              
            public constant player  NEUTRAL_PASSIVE          
            public constant integer DUMMY_UNIT_ID              
            public constant real    MAXIMUM_COLLISION_SIZE        
            public constant boolean USE_COLLISION_Z_FILTER          
            public constant boolean WRITE_DELAYED_MISSILE_RECYCLING  
            public constant boolean USE_DESTRUCTABLE_FILTER          
            public constant boolean USE_ITEM_FILTER

            readonly static constant string ORIGIN
            readonly static constant real   HIT_BOX

        // Functions:
        // ==========
            //
            public function GetLocZ               takes real x, real y returns real
                   function GetUnitBodySize       takes unit whichUnit returns real
                   function GetDestructableHeight takes destructable d returns real
                   function GetItemHeight         takes item i returns real

//========================================================================
// Missile system. Make changes carefully.
//========================================================================

//! endnovjass ( Enables the compiler )

// Hello and welcome to Missile.
// I wrote a guideline for every piece of code inside Missile, so you
// can easily understand how the it gets compiled and evaluated.
//
// Let's go!
    private keyword Init

    globals
        // Core constant handle variables of Missile.
        private constant trigger   CORE  = CreateTrigger()
        private constant trigger   MOVE  = CreateTrigger()
        private constant timer     TMR   = CreateTimer()
        private constant location  LOC   = Location(0., 0.)
        private constant rect      RECT  = Rect(0., 0., 0., 0.)
        private constant group     GROUP = CreateGroup()
        // For starting and stopping the timer.
        private integer active = 0
        // Arrays for data structure.
        private integer          array   instances
        private Missile          array   missileList
        private boolexpr         array   expression
        private triggercondition array   condition
        private integer          array   removed
        private boolean          array   destroying
        private boolean          array   recycling
        // Internal widget filter functions.
        private boolexpr destFilter
        private boolexpr itemFilter
        private boolexpr unitFilter

        private TableArray table
        private boolean fixedRotationAxes
    endglobals
   
    public function GetLocZ takes real x, real y returns real
        call MoveLocation(LOC, x, y)
        return GetLocationZ(LOC)
    endfunction

    /*
    *   Detects game version - Credits to TriggerHappy
    *   https://www.hiveworkshop.com/threads/308204/
    */
    private function IsRotationAxesFixed takes nothing returns boolean
        static if LIBRARY_GameVersion then
            return GetPatchLevel() == PATCH_LEVEL_131
        else
            local image img = CreateImage("ReplaceableTextures\\WorldEditUI\\Editor-Toolbar-MapValidation.blp", 64, 64, 0, 0,0,0,64,64,0, 1)
            local string tmp = GetLocalizedString("ERROR_ID_CDKEY_INUSE")

            if (GetHandleId(img) == -1) then
                return false
            endif
            call DestroyImage(img)

            return not ((JASS_MAX_ARRAY_SIZE <= 8192) or (GetLocalizedString("DOWNLOADING_MAP") == "DOWNLOADING_MAP") or (SubString(tmp, StringLength(tmp)-1, StringLength(tmp)) == ")") or (GetLocalizedString("WINDOW_MODE_WINDOWED") == "WINDOW_MODE_WINDOWED"))
        endif
    endfunction

    /*===============================================================================================*/

    /*
    *   One allocator for the whole library
    */
    private struct Node extends array
        static if LIBRARY_Alloc then
            implement optional Alloc
        else
            /*
            *   Credits to MyPad for the allocation algorithm
            */
            private static thistype array stack
            static method allocate takes nothing returns thistype
                local thistype node = stack[0]
                if stack[node] == 0 then
                    static if LIBRARY_ErrorMessage then
                        debug call ThrowError(node == (JASS_MAX_ARRAY_SIZE - 1), "Missile", "allocate()", "thistype", node, "Overflow")
                    endif
                    set node = node + 1
                    set stack[0] = node
                else
                    set stack[0] = stack[node]
                    set stack[node] = 0
                endif
                return node
            endmethod
            method deallocate takes nothing returns nothing
                static if LIBRARY_ErrorMessage then
                    debug call ThrowError(this == 0, "Missile", "deallocate()", "thistype", 0, "Null node")
                    debug call ThrowError(stack[this] > 0, "Missile", "deallocate()", "thistype", this, "Double-free")
                endif
                set stack[this] = stack[0]
                set stack[0] = this
            endmethod
        endif
    endstruct

    /*
    *   For calculating <effect> orientation
    */
    private struct EulerAngles extends array
        private static constant integer XY_STEPS    = 420
        private static constant integer Z_STEPS     = 270

        private static TableArray angleTable
        private static real xyDelta                 = (2.00*bj_PI)/XY_STEPS
        private static real zDelta                  = (2.00*bj_PI)/Z_STEPS
        private static integer zSteps               = 0

        readonly static real yaw                    = 0.00
        readonly static real pitch                  = 0.00
        readonly static real roll                   = 0.00

        static method from takes real xyAngle, real zAngle returns nothing
            local integer key
            set xyAngle     = ModuloReal(xyAngle, 2.00*bj_PI)
            set zAngle      = ModuloReal(zAngle, 2.00*bj_PI)
            set key         = R2I(zAngle/zDelta)*XY_STEPS + R2I(xyAngle/xyDelta)
            set yaw         = angleTable[0].real[key]
            set pitch       = angleTable[1].real[key]
            set roll        = angleTable[2].real[key]
        endmethod

        /*
        *   Based on Cyclotrutan's algorithm
        *   https://www.hiveworkshop.com/threads/orienteffect.313410/
        */
        private static method initAngles takes integer key, real dx, real dy, real dz returns nothing
            local real N = dx*dx + dy*dy
            local real norm = N + dz*dz
            local real cp
            local real pitch

            if norm == 0 then
                return
            endif

            set norm = 1.00001*SquareRoot(norm)

            set dx = dx/norm
            set dy = dy/norm
            set dz = dz/norm

            if N == 0 then
                set angleTable[0].real[key] = 0.00
                set angleTable[2].real[key] = 0.00

                if dz > 0 then
                    set angleTable[1].real[key] = -bj_PI*0.5
                else
                    set angleTable[1].real[key] = bj_PI*0.5
                endif

                return
            endif

            set N = SquareRoot(N)

            if dy < 0 then
                set pitch = Asin(dx*dz/N) + bj_PI
                set cp = Cos(pitch)

                if fixedRotationAxes then
                    set angleTable[0].real[key] = Acos(dx/cp)
                    set angleTable[2].real[key] = -Asin(dy*dz/(N*cp)) + bj_PI
                else
                    set angleTable[0].real[key] = -Asin(dy*dz/(N*cp)) + bj_PI
                    set angleTable[2].real[key] = Acos(dx/cp)
                endif
            else
                set pitch = -Asin(dx*dz/N)
                set cp = Cos(pitch)

                if fixedRotationAxes then
                    set angleTable[0].real[key] = Acos(dx/cp)
                    set angleTable[2].real[key] = Asin(dy*dz/(N*cp))
                else
                    set angleTable[0].real[key] = Asin(dy*dz/(N*cp))
                    set angleTable[2].real[key] = Acos(dx/cp)
                endif
            endif
            set angleTable[1].real[key] = pitch
        endmethod

        private static method initOrientationTables takes integer zStep returns nothing
            local real xy = Cos(zStep*zDelta)
            local real z = Sin(zStep*zDelta)
            local integer xySteps = 0
            loop
                exitwhen xySteps == XY_STEPS
                call initAngles(zStep*XY_STEPS + xySteps, xy*Cos(xySteps*xyDelta), xy*Sin(xySteps*xyDelta), z)
                set xySteps = xySteps + 1
            endloop
        endmethod

        private static method initTables takes nothing returns nothing
            call initOrientationTables(zSteps)
            call initOrientationTables(zSteps + Z_STEPS/2)
        endmethod

        static method onScopeInit takes nothing returns nothing
            set angleTable = TableArray[3]
            set fixedRotationAxes = IsRotationAxesFixed()
            loop
                exitwhen zSteps == Z_STEPS/2
                call ForForce(bj_FORCE_PLAYER[0], function thistype.initTables)
                set zSteps = zSteps + 1
            endloop
        endmethod
    endstruct

    /*
    *   List of <effect>s
    */
    private struct EffectHandle extends array
        effect effect

        private static method onRemove takes thistype node returns nothing
            call DestroyEffect(node.effect)
            set node.effect = null
            call Node(node).deallocate()
        endmethod

        private static method allocate takes nothing returns thistype
            return Node.allocate()
        endmethod
        private method deallocate takes nothing returns nothing
            call Node(this).deallocate()
        endmethod

        implement InstantiatedList
    endstruct

    /*
    *   Effect is a cluster of <effect>s that can easily be controlled as a single object
    */
    private struct Effect extends array
        private static TableArray lookupTable

        private method operator handle takes nothing returns EffectHandle
            return this
        endmethod

        method operator missile takes nothing returns Missile
            return this
        endmethod

        method addModel takes string model returns effect
            local EffectHandle node = Node.allocate()
            set lookupTable[this][StringHash(model)] = node
            set node.effect = AddSpecialEffect(model, this.missile.x, this.missile.y)
            call BlzSetSpecialEffectZ(node.effect, this.missile.z)
            call BlzSetSpecialEffectScale(node.effect, this.missile.scale)
            call this.handle.pushBack(node)
            return node.effect
        endmethod
        method removeModel takes string model returns nothing
            local integer stringId = StringHash(model)
            call EffectHandle.remove(lookupTable[this][stringId])
            call lookupTable[this].remove(stringId)
        endmethod
        method clearModels takes nothing returns nothing
            call this.handle.flush()
            call lookupTable[this].flush()
        endmethod

        method getHandle takes string model returns effect
            return EffectHandle(lookupTable[this][StringHash(model)]).effect
        endmethod

        method scale takes real value returns nothing
            local EffectHandle node = this.handle.next
            loop
                exitwhen node == this.handle
                call BlzSetSpecialEffectScale(node.effect, value)
                set node = node.next
            endloop
        endmethod

        method move takes real x, real y, real z returns nothing
            local EffectHandle node = this.handle.next
            local real dx = x - this.missile.x
            local real dy = y - this.missile.y
            local real dz = z - this.missile.z
            static if not LIBRARY_BoundSentinel and not LIBRARY_WorldBounds then
                if not RectContainsCoords(bj_mapInitialPlayableArea, x, y) then
                    return
                endif
            elseif LIBRARY_WorldBounds then
                if not (x < WorldBounds.maxX and x > WorldBounds.minX and y < WorldBounds.maxY and y > WorldBounds.minY) then
                    return
                endif
            endif
            loop
                exitwhen node == this.handle
                call BlzSetSpecialEffectPosition(node.effect, BlzGetLocalSpecialEffectX(node.effect) + dx, BlzGetLocalSpecialEffectY(node.effect) + dy, BlzGetLocalSpecialEffectZ(node.effect) + dz)
                set node = node.next
            endloop
        endmethod

        method orient takes real xyAngle, real pitch returns nothing
            local EffectHandle node = this.handle.next
            call EulerAngles.from(xyAngle, pitch)
            loop
                exitwhen node == this.handle
                call BlzSetSpecialEffectOrientation(node.effect, EulerAngles.yaw, EulerAngles.pitch, EulerAngles.roll)
                set node = node.next
            endloop
        endmethod

        static method create takes nothing returns thistype
            return EffectHandle.create()
        endmethod
        method destroy takes nothing returns nothing
            call lookupTable[this].flush()
            call this.handle.destroy()
        endmethod

        static method onScopeInit takes nothing returns nothing
            set lookupTable = TableArray[JASS_MAX_ARRAY_SIZE]
        endmethod
    endstruct

    // Simple trigonometry.
    struct MissilePosition extends array
        readonly real x
        readonly real y
        readonly real z
        readonly real angle
        readonly real distance
        readonly real square
        readonly real slope
        readonly real alpha

        // Creates an origin - impact link.
        private thistype ref

        private static method math takes thistype a, thistype b returns nothing
            local real dx
            local real dy
            loop
                set dx = b.x - a.x
                set dy = b.y - a.y
                set dx = dx*dx + dy*dy
                set dy = SquareRoot(dx)
                exitwhen dx != 0. and dy != 0.
                set b.x = b.x + .01
                set b.z = b.z - Missile_GetLocZ(b.x -.01, b.y) + Missile_GetLocZ(b.x, b.y)
            endloop

            set a.square   = dx
            set a.distance = dy
            set a.angle    = Atan2(b.y - a.y, b.x - a.x)
            set a.slope    = (b.z - a.z)/dy
            set a.alpha    = Atan(a.slope)*bj_RADTODEG
            // Set b.
            if b.ref == a then
                set b.angle     = a.angle + bj_PI
                set b.distance  = dy
                set b.slope     = -a.slope
                set b.alpha     = -a.alpha
                set b.square    = dx
            endif
        endmethod

        static method link takes thistype a, thistype b returns nothing
            set a.ref = b
            set b.ref = a
            call math(a, b)
        endmethod

        method move takes real toX, real toY, real toZ returns nothing
            set x = toX
            set y = toY
            set z = toZ + Missile_GetLocZ(toX, toY)
            if ref != this then
                call math(this, ref)
            endif
        endmethod

        static method create takes real x, real y, real z returns MissilePosition
            local thistype this = Node.allocate()
            set ref = this
            call move(x, y, z)
            return this
        endmethod
        method destroy takes nothing returns nothing
            call Node(this).deallocate()
        endmethod

    endstruct

    struct MissileList extends array
        method operator missile takes nothing returns Missile
            return this
        endmethod
        implement StaticList
    endstruct

    struct Missile extends array

        // Attach point name for effects created by model=.
        readonly static constant string ORIGIN = "origin"

        // Set a ficitional hit box in range of 0 to 1,
        // while 0 is the toe and 1 the head of a unit.
        readonly static constant real HIT_BOX  = (2./3.)

        // Checks for double launching. Throws an error message.
        debug boolean launched

        // The position of a missile using curve= does not
        // match the position used by Missile's trigonometry.
        // Therefore we need this member two times.
        // Readable x / y / z for your needs and posX / posY for cool mathematics.
        private real posX
        private real posY
        private real dist// distance

        // Readonly members:
        // =================
        //
        // Prevents a double free case.
        readonly boolean allocated

        // The dummy unit.
        readonly unit    dummy

        // Position members for your needs.
        readonly MissilePosition origin// Grants access to readonly members of MissilePosition,
        readonly MissilePosition impact// which are "x", "y", "z", "angle", "distance", "slope" and "alpha".
        readonly real            terrainZ
        readonly real            x
        readonly real            y
        readonly real            z
        readonly real            angle// Current angle
        readonly real            prevX
        readonly real            prevY
        readonly real            prevZ

        // Collision detection type. ( Evaluated new in each loop )
        readonly integer         collisionType// Current collision type ( circular or rectangle )

        unit       source
        unit       target      // For homing missiles.
        real       distance    // Distance traveled.
        player     owner       // Pseudo owner for faster onCollide evaluation. The proper dummy owner is PLAYER_NEUTRAL_PASSIVE.
        real       speed       // Vector lenght for missile movement in plane x / y.
        real       acceleration
        real       damage
        integer    data        // For data transfer set and read data.
        boolean    recycle     // Is set to true, when a Missile reaches it's destination.
        real       turn        // Sets a turn rate for a missile.
        real       collision   // Collision size in plane x / y.

        private static method onInsert takes thistype node returns nothing
            call MissileList.pushBack(node)
        endmethod
        private static method onRemove takes thistype node returns nothing
            call MissileList.remove(node)
        endmethod
        implement List

        static method p_makeHead takes thistype node returns nothing
            set node.prev = node
            set node.next = node
        endmethod

        method operator effect takes nothing returns Effect
            return this
        endmethod

        // Setting collision z is deprecated since Missile v2.5.
        method operator collisionZ= takes real value returns nothing
        endmethod
        method operator collisionZ takes nothing returns real
            return collision
        endmethod

        method operator sfx takes nothing returns effect
            return null
        endmethod

        private string path
        method operator model= takes string file returns nothing
            call effect.clearModels()
            // null and ""
            if StringLength(file) > 0 then
                call effect.addModel(file)
                set path = file
            else
                set path = null
            endif
        endmethod
        method operator model takes nothing returns string
            return path
        endmethod

        real open
        // Enables curved movement for your missile.
        // Remember that the result of Tan(PI/2) is infinity.
        method operator curve= takes real value returns nothing
            set open = Tan(value)*origin.distance
        endmethod
        method operator curve takes nothing returns real
            return Atan(open/origin.distance)
        endmethod

        private real height
        // Enables arcing movement for your missile.
        method operator arc= takes real value returns nothing
            set height = Tan(value)*origin.distance/4
        endmethod
        method operator arc takes nothing returns real
            return Atan(4*height/origin.distance)
        endmethod

        private real scaling
        method operator scale= takes real value returns nothing
            call SetUnitScale(dummy, value, 0., 0.)
            call effect.scale(value)
            set scaling = value
        endmethod
        method operator scale takes nothing returns real
            return scaling
        endmethod

        method bounce takes nothing returns nothing
            call origin.move(x, y, z)
            set dist = 0.
        endmethod

        method deflect takes real tx, real ty returns nothing
            local real a = 2.*Atan2(ty - y, tx - x) + bj_PI - angle
            call impact.move(x + (origin.distance - dist)*Cos(a), y + (origin.distance - dist)*Sin(a), impact.z)
            call bounce()
        endmethod

        method deflectEx takes real tx, real ty, real tz returns nothing
            call impact.move(impact.x, impact.y, tz)
            call deflect(tx, ty)
        endmethod

        method flightTime2Speed takes real duration returns nothing
            set speed = RMaxBJ(0.00000001, (origin.distance - dist)*Missile_TIMER_TIMEOUT/RMaxBJ(0.00000001, duration))
        endmethod

        method setMovementSpeed takes real value returns nothing
            set speed = value*Missile_TIMER_TIMEOUT
        endmethod

        boolean wantDestroy// For "true" a missile is destroyed on the next timer callback. 100% safe.
        method destroy takes nothing returns nothing
            set wantDestroy = true
        endmethod

        // Instantly destroys a missile.
        method terminate takes nothing returns nothing
            if allocated then
                set allocated = false
                call impact.destroy()
                call origin.destroy()

                call table[this].flush()
                set source = null
                set target = null
                set dummy = null
                set owner = null

                call this.effect.destroy()
                call remove(this)
            endif
        endmethod

        // Runs in createEx.
        private method resetMembers takes nothing returns nothing
            set path = null
            set speed = 0.
            set acceleration = 0.
            set distance = 0.
            set dist = 0.
            set height = 0.
            set turn = 0.
            set open = 0.
            set collision = 0.
            set collisionType = 0
            set stackSize = 0
            set scaling = 1.
            set wantDestroy = false
            set recycle = false
        endmethod

        // Launches a dummy of your choice.
        static method createEx takes unit missileDummy, real impactX, real impactY, real impactZ returns thistype
            local real originX  = GetUnitX(missileDummy)
            local real originY  = GetUnitY(missileDummy)
            local real originZ  = GetUnitFlyHeight(missileDummy)
            local thistype this = Effect.create()

            call resetMembers()

            set origin = MissilePosition.create(originX, originY, originZ)
            set impact = MissilePosition.create(impactX, impactY, impactZ)
            call MissilePosition.link(origin, impact)

            set posX      = originX
            set posY      = originY
            set x         = originX
            set y         = originY
            set z         = originZ
            set angle     = origin.angle
            set dummy     = missileDummy
            set allocated = true

            if UnitAddAbility(missileDummy, 'Arav') then
                call UnitRemoveAbility(missileDummy, 'Arav')
            endif

            call SetUnitFlyHeight(missileDummy, originZ, 0.)
            set table[this].unit[GetHandleId(missileDummy)] = missileDummy

            static if LIBRARY_ErrorMessage then
                debug call ThrowWarning(GetUnitTypeId(missileDummy) == 0, "Missile", "createEx", "missileDummy", this, "Invalid missile dummy unit ( null )!")
            endif
            debug set launched = false
            return this
        endmethod

        // Wrapper to createEx.
        static method create takes real x, real y, real z, real angle, real distance, real impactZ returns thistype
            local real impactX = x + distance*Cos(angle)
            local real impactY = y + distance*Sin(angle)
            local thistype this = Effect.create()

            call resetMembers()

            set origin = MissilePosition.create(x, y, z)
            set impact = MissilePosition.create(impactX, impactY, impactZ)
            call MissilePosition.link(origin, impact)

            set .posX       = x
            set .posY       = y
            set .x          = x
            set .y          = y
            set .z          = z
            set angle       = origin.angle
            set dummy       = null
            set allocated   = true

            debug set launched = false
            return this
        endmethod

        static method createXYZ takes real x, real y, real z, real impactX, real impactY, real impactZ returns thistype
            local real dx = impactX - x
            local real dy = impactY - y
            local real dz = impactZ - z

            return create(x, y, z, Atan2(dy, dx), SquareRoot(dx*dx + dy*dy), impactZ)
        endmethod

        // Missile motion takes place every Missile_TIMER_TIMEOUT
        // before accessing each active struct.
        static Missile temp = 0
        static method move takes nothing returns boolean
            local integer loops = 0   // Current iteration.
            local integer limit = 150 // Set iteration border per trigger evaluation to avoid hitting the operation limit.
            local thistype this = thistype.temp

            local MissilePosition p
            local real a
            local real d
            local unit u
            local real newX
            local real newY
            local real newZ
            local real vel
            local real point
            loop
                exitwhen this == MissileList.head or loops == limit
                set p = origin

                // Save previous, respectively current missile position.
                set prevX = x
                set prevY = y
                set prevZ = z

                // Evaluate the collision type.
                set vel = speed
                set speed = vel + acceleration
                if vel < collision*Missile_COLLISION_ACCURACY_FACTOR then
                    set collisionType = Missile_COLLISION_TYPE_CIRCLE
                else
                    set collisionType = Missile_COLLISION_TYPE_RECTANGLE
                endif

                // Update missile guidance to its intended target.
                set u = target
                if u != null then
                    if 0 == GetUnitTypeId(u) then
                        set target = null
                    else
                        call origin.move(x, y, z)
                        call impact.move(GetUnitX(u), GetUnitY(u), GetUnitFlyHeight(u) + GetUnitBodySize(u)*Missile.HIT_BOX)
                        set dist = 0
                        set height = 0
                        set curve = 0
                    endif
                endif
                set a = p.angle

                // Update the missile facing angle depending on the turn ratio.
                if 0. != turn and Cos(angle - a) < Cos(turn) then
                    if 0. > Sin(a - angle) then
                        set angle = angle - turn
                    else
                        set angle = angle + turn
                    endif
                else
                    set angle = a
                endif

                // Update the missile position on the parabola.
                set d = p.distance// origin - impact distance.

                set recycle = dist + vel >= d
                if recycle then
                    set point = d
                    set distance = distance + d - dist
                else
                    set distance = distance + vel
                    set point = dist + vel
                endif
                set dist = point

                set newX = posX + vel*Cos(angle)
                set newY = posY + vel*Sin(angle)
                set posX = newX
                set posY = newY

                // Update point(x/y) if a curving trajectory is defined.
                set u = dummy
                if 0. != open and target == null then
                    set vel = 4*open*point*(d - point)/p.square
                    set a = angle + bj_PI/2
                    set newX = newX + vel*Cos(a)
                    set newY = newY + vel*Sin(a)
                    set a = angle + Atan(-((4*open)*(2*point - d))/p.square)
                else
                    set a = angle
                endif

                // Update pos z if an arc or height is set.
                call MoveLocation(LOC, newX, newY)
                set terrainZ = GetLocationZ(LOC)
                if 0. == height and 0. == p.alpha then
                    set newZ = p.z - terrainZ
                else
                    set newZ = p.z - terrainZ + p.slope*point
                    if 0. != height and target == null then
                        set newZ = newZ + (4*height*point*(d - point)/p.square)
                    endif
                endif

                // Set missile position and orientation
                call .effect.move(newX, newY, newZ)
                call .effect.orient(a, Atan2(newZ - prevZ, vel))

                if u != null then
                    call SetUnitFlyHeight(u, newZ, 0.)
                    call SetUnitFacing(u, a*bj_RADTODEG)
                    call SetUnitLookAt(u, "bone_head", u, 2.*newX - prevX, 2.*newY - prevY, 2.*newZ - prevZ)

                    // WorldBounds > BoundSentinel.
                    static if not LIBRARY_BoundSentinel and not LIBRARY_WorldBounds then
                        if RectContainsCoords(bj_mapInitialPlayableArea, newX, newY) then
                            call SetUnitX(u, newX)
                            call SetUnitY(u, newY)
                        endif
                    elseif LIBRARY_WorldBounds then
                        if newX < WorldBounds.maxX and newX > WorldBounds.minX and newY < WorldBounds.maxY and newY > WorldBounds.minY then
                            call SetUnitX(u, newX)
                            call SetUnitY(u, newY)
                        endif
                    else
                        call SetUnitX(u, newX)
                        call SetUnitY(u, newY)
                    endif
                endif

                set .x = newX
                set .y = newY
                set .z = newZ

                set loops = loops + 1
                set this = MissileList(this).next
            endloop

            set u = null
            set thistype.temp = this
            return this == MissileList.head
        endmethod
           
        // Widget collision API:
        // =====================
        //
        // Runs automatically on widget collision.
        method hitWidget takes widget w returns nothing
            if w != null then
                set table[this].widget[GetHandleId(w)] = w
            endif
        endmethod

        // All widget which have been hit return true.
        method hasHitWidget takes widget w returns boolean
            return table[this].handle.has(GetHandleId(w))
        endmethod

        // Removes a widget from the missile's memory of hit widgets. ( This widget can be hit again )
        method removeHitWidget takes widget w returns nothing
            if w != null then
                call table[this].handle.remove(GetHandleId(w))
            endif
        endmethod

        // Flushes a missile's memory for collision. ( All widgets can be hit again )
        method flushHitWidgets takes nothing returns nothing
            call table[this].flush()
            call hitWidget(dummy)
        endmethod

        // Tells missile to call removeHitWidget(w) after "seconds" time.
        // Does not apply to widgets, which are already hit by this missile.
        readonly integer stackSize
        method enableHitAfter takes widget w, real seconds returns nothing
            local integer id = GetHandleId(w)
            local Table t
            if w != null then
                set t = table[this]
                if not t.has(id) then
                    set t[id] = stackSize
                    set t[stackSize] = id
                    set stackSize = stackSize + 1
                endif
                set t.real[id] = seconds
            endif
        endmethod

        method updateStack takes nothing returns nothing
            local integer dex = 0
            local integer id
            local real time
            local Table t
            loop
                exitwhen dex == stackSize
                set t = table[this]
                set id = t[dex]
                set time = t.real[id] - Missile_TIMER_TIMEOUT
                if time <= 0. or not t.handle.has(id) then
                    set stackSize = stackSize - 1
                    set id = t[stackSize]
                    set t[dex] = id
                    set t[id] = dex
                    // Enables hit.
                    call t.handle.remove(id)
                    // Remove data from stack.
                    call t.real.remove(id)
                    call t.remove(id)
                    call t.remove(stackSize)
                else
                    set t.real[id] = time
                    set dex = dex + 1
                endif
            endloop
        endmethod

        // Widget collision code:
        // ======================
        //
        private static boolean circle = true
        //
        // 1.) Rectangle collision for fast moving missiles with small collision radius.
        //
        // Runs for destructables and items in a rectangle.
        // Checks if widget w is in collision range of a missile.
        // Is not precise in z - axis collision.
        private method isWidgetInRectangle takes widget w, real wz, real distance returns boolean
            local real wx = GetWidgetX(w)
            local real wy = GetWidgetY(w)
            local real dz = Missile_GetLocZ(wx, wy) - terrainZ
            local real dx = x - prevX
            local real dy = y - prevY
            local real s  = (dx*(wx - prevX) + dy*(wy - prevY))/(dx*dx + dy*dy)

            if s < 0. then
                set s = 0.
            elseif s > 1 then
                set s = 1.
            endif
            set dx = (prevX + s*dx) - wx
            set dy = (prevY + s*dy) - wy

            return dx*dx + dy*dy <= distance*distance and dz + wz >= z - distance and dz <= z + distance
        endmethod
        //
        // 2.) Circular collision detection for all other missiles.
        //
        // Returns true for widgets in a xyz collision range.
        private method isWidgetInRange takes widget w, real wz, real distance returns boolean
            local real wx = GetWidgetX(w)
            local real wy = GetWidgetY(w)
            local real dz = Missile_GetLocZ(wx, wy) - terrainZ
            //     collision in plane x and y,            collision in z axis.
            return IsUnitInRangeXY(dummy, wx, wy, distance) and dz + wz >= z - distance and dz <= z + distance
        endmethod
        //
        //  3.) Action functions inside the widget enumeration thread.
        //
        // Runs for every enumerated destructable.
        //  • Directly filters out already hit destructables.
        //  • Distance formula based on the Pythagorean theorem.
        //                      
        private static method filterDests takes nothing returns boolean
            local destructable d = GetFilterDestructable()
            local boolean b = false
            if not table[temp].handle.has(GetHandleId(d)) then
                if circle then
                    set b = temp.isWidgetInRange(d, GetDestructableHeight(d), temp.collision)
                else
                    set b = temp.isWidgetInRectangle(d, GetDestructableHeight(d), temp.collision)
                endif
            endif
            set d = null
            return b
        endmethod
        //
        // Runs for every enumerated item.
        //  • Directly filters out already hit items.
        //  • Distance formula based on the Pythagorean theorem.
        //  • Items have a fix collision size of 16.
        //
        private static method filterItems takes nothing returns boolean
            local item i = GetFilterItem()
            local boolean b = false
            if not table[temp].handle.has(GetHandleId(i)) then
                if circle then                                        // Item in missile collision size or item pathing in missile range.
                    set b = temp.isWidgetInRange(i, GetItemHeight(i), RMaxBJ(temp.collision, 16.))
                else
                    set b = temp.isWidgetInRectangle(i, GetItemHeight(i), RMaxBJ(temp.collision, 16.))
                endif
            endif
            set i = null
            return b
        endmethod
        //
        //  4.) Filter function for rectangle unit collision.
        //
        // Runs for every enumerated units.
        //  • Filters out units which are not in collision range in plane x / y.
        //  • Inlined and therefore a bit faster than item and destructable collision.
        //
        private static method filterUnits takes nothing returns boolean
            local thistype this = thistype.temp
            local unit u = GetFilterUnit()
            local real dx
            local real dy
            local real s
            local boolean is = false

            if not table[this].handle.has(GetHandleId(u)) then
                set dx = x - prevX
                set dy = y - prevY
                set s = (dx*(GetUnitX(u) - prevX) + dy*(GetUnitY(u)- prevY))/(dx*dx + dy*dy)
                if s < 0. then
                    set s = 0.
                elseif s > 1. then
                    set s = 1.
                endif
                set is = IsUnitInRangeXY(u, prevX + s*dx, prevY + s*dy, collision)
            endif
           
            set u = null
            return is
        endmethod
        //
        // 5.) Proper rect preparation.
        //
        // For rectangle.
        private method prepareRectRectangle takes nothing returns nothing
            local real x1 = prevX
            local real y1 = prevY
            local real x2 = x
            local real y2 = y
            local real d = collision + Missile_MAXIMUM_COLLISION_SIZE
            // What is min, what is max ...
            if x1 < x2 then
                if y1 < y2 then
                    call SetRect(RECT, x1 - d, y1 - d, x2 + d, y2 + d)
                else
                    call SetRect(RECT, x1 - d, y2 - d, x2 + d, y1 + d)
                endif
            elseif y1 < y2 then
                call SetRect(RECT, x2 - d, y1 - d, x1 + d, y2 + d)
            else
                call SetRect(RECT, x2 - d, y2 - d, x1 + d, y1 + d)
            endif
        endmethod
        //
        // For circular.
        private method prepareRectCircle takes nothing returns nothing
            local real d = collision + Missile_MAXIMUM_COLLISION_SIZE
            call SetRect(RECT, x - d, y - d, x + d, y + d)
        endmethod
        //
        // 5.) API for the MissileStruct iteration.
        //
        method groupEnumUnitsRectangle takes nothing returns nothing
            call prepareRectRectangle()
            set thistype.temp = this
            call GroupEnumUnitsInRect(GROUP, RECT, unitFilter)
        endmethod
        //
        // Prepares destructable enumeration, then runs enumDests.
        method checkDestCollision takes code func returns nothing
            set circle = collisionType == Missile_COLLISION_TYPE_CIRCLE
            if circle then
                call prepareRectCircle()
            else
                call prepareRectRectangle()
            endif

            set thistype.temp = this
            call EnumDestructablesInRect(RECT, destFilter, func)
        endmethod
        //
        // Prepares item enumeration, then runs enumItems.
        method checkItemCollision takes code func returns nothing
            set circle = collisionType == Missile_COLLISION_TYPE_CIRCLE
            if circle then
                call prepareRectCircle()
            else
                call prepareRectRectangle()
            endif

            set thistype.temp = this
            call EnumItemsInRect(RECT, itemFilter, func)
        endmethod

static if Missile_WRITE_DELAYED_MISSILE_RECYCLING then
    method nullBefore takes nothing returns nothing
    endmethod
endif

// Does not check for 'Aloc' and 'Amrf' as they could be customized.
        private static method onScopeInit takes nothing returns nothing
            static if LIBRARY_ErrorMessage then
                debug call ThrowError((Missile_MAXIMUM_COLLISION_SIZE < 0), "Missile", "DEBUG_MISSILE", "collision",  0, "Global setup for public real MAXIMUM_COLLISION_SIZE is incorrect, below zero! This map currently can't use Missile!")
            endif

            set unitFilter = Filter(function thistype.filterUnits)
            set destFilter = Filter(function thistype.filterDests)
            set itemFilter = Filter(function thistype.filterItems)
            call TriggerAddCondition(MOVE, Condition(function thistype.move))

            set table = TableArray[JASS_MAX_ARRAY_SIZE]
        endmethod
        implement Init
    endstruct

    // Boolean expressions per struct:
    // ===============================
    //
    // Condition function for the core trigger evaluation. ( Runs for all struct using module MissileStruct )
    private function MissileCreateExpression takes integer structId, code func returns nothing
        set expression[structId] = Condition(func)
    endfunction

    // Creates a collection for a struct. ( Runs for all struct using module MissileStruct )
    private function MissileCreateCollection takes integer structId returns nothing
        local Missile node = Node.allocate()
        call Missile.p_makeHead(node) // Make a circular list
        set missileList[structId] = node
    endfunction

    // Core:
    // =====
    //
    // Fires every Missile_TIMER_TIMEOUT.
    private function Fire takes nothing returns nothing
        local integer i = removed[0]
        set removed[0] = 0
        loop
            exitwhen 0 == i
            if recycling[i] then
                call TriggerRemoveCondition(CORE, condition[i])
                set condition[i] = null
                set active = active - 1
            endif
            set destroying[i] = false
            set recycling[i] = false
            set i = removed[i]
        endloop

        if 0 == active then
            call PauseTimer(TMR)
        else
            // Move all launched missiles.
            //set Missile.temp = nextNode[0]
            set Missile.temp = MissileList.front
            set i = 0
            loop
                exitwhen TriggerEvaluate(MOVE)
                exitwhen i == 60// Moved over 8910 missiles, something buggy happened.
                set i = i + 1   // This case is impossible, hence never happens. But if I'm wrong, which also never happens
            endloop             // then the map 100% crashes. i == 66 will prevent the game crash and Missile will start to
                                // to debug itself over the next iterations.

            // Access all structs using module MissileStruct.
            static if DEBUG_MODE and LIBRARY_ErrorMesssage then
                if not TriggerEvaluate(CORE) then
                    call ThrowWarning(true, "Missile", "Fire", "op limit", 0, /*
*/"You just ran into a op limit!
The op limit protection of Missile is insufficient for your map.
The code of the missile module can't run in one thread and must be splitted.
If unsure make a post in the official 'The Hive Workshop' forum thread of Missile!")
                endif
            else
                call TriggerEvaluate(CORE)
            endif
        endif
    endfunction

    // Conditionally starts the timer.
    private function StartPeriodic takes integer structId returns nothing
        if 0 == instances[structId] or destroying[structId] then          
            if destroying[structId] then
                set recycling[structId] = false
            else
                if 0 == active then
                    call TimerStart(TMR, Missile_TIMER_TIMEOUT, true, function Fire)
                endif
                set active = active + 1
                set condition[structId] = TriggerAddCondition(CORE, expression[structId])
            endif
        endif
        set instances[structId] = instances[structId] + 1
    endfunction
   
    // Conditionally stops the timer in the next callback.
    private function StopPeriodic takes integer structId returns nothing
        set instances[structId] = instances[structId] - 1
        if 0 == instances[structId] and condition[structId] != null then
            if not destroying[structId] and not recycling[structId] then
                set destroying[structId] = true
                set recycling[structId] = true
                set removed[structId] = removed[0]
                set removed[0] = structId
            endif
        endif
    endfunction

    // Modules:
    // ========
    //
    // You want to place module MissileLaunch at the very top of your struct.
    module MissileLaunch
        static method launch takes Missile missile returns nothing
            static if LIBRARY_ErrorMessage then
                debug call ThrowError(missile.launched, "thistype", "launch", "missile.launched", missile, "This missile was already launched before!")
            endif
            debug set missile.launched = true

            call missileList[thistype.typeid].pushBack(missile)
            call StartPeriodic(thistype.typeid)
        endmethod
    endmodule

    module MissileTerminate
        // Called from missileIterate. "P" to avoid code collision.
        static method missileTerminateP takes Missile node returns nothing
            if node.allocated then
                static if thistype.onRemove.exists then
                    call thistype.onRemove(node)
                endif

                call node.terminate()
                call StopPeriodic(thistype.typeid)
            endif
        endmethod
    endmodule

    // Allows you to inject missile in certain stages of the motion process.
    module MissileAction

static if DEBUG_MODE then
    // Runs check during compile time.
    static if thistype.onMissile.exists then
        Error Message from library Missile in struct thistype !
        thistype.onMissile is a reserved name for Missile, once you implemented MissileStruct.
        thistype.onMissile is currently not supported by library Missile.
        Please delete or re-name that method.
    endif
endif

    static if thistype.onItem.exists then
        private static method missileActionItem takes nothing returns nothing
            local item i = GetEnumItem()
            local Missile this = Missile.temp
            if this.allocated then
                set table[this].item[GetHandleId(i)] = i
                if thistype.onItem(this, i) then
                    call missileTerminateP(this)
                endif
            endif
            set i = null
        endmethod
    endif
       
    static if thistype.onDestructable.exists then
        private static method missileActionDest takes nothing returns nothing
            local destructable d = GetEnumDestructable()
            local Missile this = Missile.temp
            if this.allocated then
                set table[this].destructable[GetHandleId(d)] = d
                if thistype.onDestructable(this, d) then
                    call missileTerminateP(this)
                endif
            endif
            set d = null
        endmethod
    endif

        // Runs every Missile_TIMER_TIMEOUT for this struct.
        static method missileIterateP takes nothing returns boolean
            local Missile this = missileList[thistype.typeid].front
            local Missile node
            local real collideZ
            local boolean b
            local unit u

            loop
                exitwhen this == missileList[thistype.typeid]
                set node = this.next// The linked list should not lose the next node.

                if this.wantDestroy then
                    call thistype.missileTerminateP(this)
                else
                    if this.stackSize > 0 then
                        call this.updateStack()
                    endif

                    // Runs unit collision.
                    static if thistype.onCollide.exists then
                        if this.allocated and 0. < this.collision then
                            set b = this.collisionType == Missile_COLLISION_TYPE_RECTANGLE
                            if b then
                                call this.groupEnumUnitsRectangle()
                            else
                                call GroupEnumUnitsInRange(GROUP, this.x, this.y, this.collision + Missile_MAXIMUM_COLLISION_SIZE, null)
                            endif
                            loop
                                set u = FirstOfGroup(GROUP)
                                exitwhen u == null
                                call GroupRemoveUnit(GROUP, u)
                                if not table[this].handle.has(GetHandleId(u)) then
                                    if b or (this.dummy == null and IsUnitInRangeXY(u, this.x, this.y, this.collision)) or IsUnitInRange(u, this.dummy, this.collision) then
                                        // Eventually run z collision checks.
                                        static if Missile_USE_COLLISION_Z_FILTER then
                                            set collideZ = Missile_GetLocZ(GetUnitX(u), GetUnitY(u)) + GetUnitFlyHeight(u) - this.terrainZ
                                            if (collideZ + GetUnitBodySize(u) >= this.z - this.collisionZ) and (collideZ <= this.z + this.collisionZ) then
                                                // Mark as hit.
                                                set table[this].unit[GetHandleId(u)] = u
                                                if thistype.onCollide(this, u) then
                                                    call thistype.missileTerminateP(this)
                                                    exitwhen true
                                                endif
                                            endif
                                        else
                                            // Runs unit collision without z collision checks.
                                            set table[this].unit[GetHandleId(u)] = u
                                            if thistype.onCollide(this, u) then
                                                call thistype.missileTerminateP(this)
                                                exitwhen true
                                            endif
                                        endif
                                    endif
                                endif
                            endloop
                        endif
                    endif

                    // Runs destructable collision.
                    static if thistype.onDestructable.exists then
                        // Check if the missile is not terminated.
                        if this.allocated and 0. < this.collision then
                            call this.checkDestCollision(function thistype.missileActionDest)
                        endif
                    endif

                    // Runs item collision.
                    static if thistype.onItem.exists then
                        //  Check if the missile is not terminated.
                        if this.allocated and 0. < this.collision then
                            call this.checkItemCollision(function thistype.missileActionItem)
                        endif
                    endif

                    // Runs when the destination is reached.
                    if this.recycle and this.allocated then
                        static if thistype.onFinish.exists then
                            if thistype.onFinish(this) then
                                call thistype.missileTerminateP(this)
                            endif
                        else
                            call thistype.missileTerminateP(this)
                        endif
                    endif

                    // Runs on terrian collision.
                    static if thistype.onTerrain.exists then
                        if this.allocated and 0. > this.z and thistype.onTerrain(this) then
                            call missileTerminateP(this)
                        endif
                    endif

                    // Runs every Missile_TIMER_TIMEOUT.
                    static if thistype.onPeriod.exists then
                        if this.allocated and thistype.onPeriod(this) then
                            call missileTerminateP(this)
                        endif
                    endif
                endif
                set this = node
            endloop

            set u = null
            static if DEBUG_MODE and LIBRARY_ErrorMessage then
                return true
            else
                return false
            endif
        endmethod
    endmodule

    module MissileStruct
        implement MissileLaunch
        implement MissileTerminate
        implement MissileAction

        private static method onInit takes nothing returns nothing
            call MissileCreateCollection(thistype.typeid)
            call MissileCreateExpression(thistype.typeid, function thistype.missileIterateP)
        endmethod
    endmodule

    private module Init
        private static method onInit takes nothing returns nothing
            call EulerAngles.onScopeInit()
            call Effect.onScopeInit()
            call Missile.onScopeInit()
        endmethod
    endmodule

// The end!
endlibrary