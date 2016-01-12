use v5;

package Perlito5::Javascript2::Array;

sub emit_javascript2 {

    return <<'EOT';
//
// lib/Perlito5/Javascript2/Runtime.js
//
// Runtime for "Perlito" Perl5-in-Javascript2
//
// AUTHORS
//
// Flavio Soibelmann Glock  fglock@gmail.com
//
// COPYRIGHT
//
// Copyright 2009, 2010, 2011, 2012 by Flavio Soibelmann Glock and others.
//
// This program is free software; you can redistribute it and/or modify it
// under the same terms as Perl itself.
//
// See http://www.perl.com/perl/misc/Artistic.html

//-------- Array 

Object.defineProperty( Array.prototype, "p5aget", {
    enumerable : false,
    value : function (i) {
        if (i < 0) { i =  this.length + i };
        return this[i] 
    }
});
Object.defineProperty( Array.prototype, "p5aset", {
    enumerable : false,
    value : function (i, v) {
        if (i < 0) { i =  this.length + i };
        this[i] = v;
        return this[i]
    }
});

Object.defineProperty( Array.prototype, "p5incr", {
    enumerable : false,
    value : function (i) {
        if (i < 0) { i =  this.length + i };
        this[i] = p5incr_(this[i]);
        return this[i];
    }
});
Object.defineProperty( Array.prototype, "p5postincr", {
    enumerable : false,
    value : function (i) {
        if (i < 0) { i =  this.length + i };
        var v = this[i];
        this[i] = p5incr_(this[i]);
        return v;
    }
});
Object.defineProperty( Array.prototype, "p5decr", {
    enumerable : false,
    value : function (i) {
        if (i < 0) { i =  this.length + i };
        this[i] = p5decr_(this[i]);
        return this[i];
    }
});
Object.defineProperty( Array.prototype, "p5postdecr", {
    enumerable : false,
    value : function (i) {
        if (i < 0) { i =  this.length + i };
        var v = this[i];
        this[i] = p5decr_(this[i]);
        return v;
    }
});

Object.defineProperty( Array.prototype, "p5aget_array", {
    enumerable : false,
    value : function (i) {
        if (i < 0) { i =  this.length + i };
        if (this[i] == null) { this[i] = new p5ArrayRef([]) }
        return this[i]
    }
});
Object.defineProperty( Array.prototype, "p5aget_hash", {
    enumerable : false,
    value : function (i) {
        if (i < 0) { i =  this.length + i };
        if (this[i] == null) { this[i] = new p5HashRef({}) }
        return this[i]
    }
});
Object.defineProperty( Array.prototype, "p5unshift", {
    enumerable : false,
    configurable : true,
    value : function (args) { 
        for(var i = args.length-1; i >= 0; i--) {
            this.unshift(args[i]);
        }
        return this.length; 
    }
});
Object.defineProperty( Array.prototype, "p5push", {
    enumerable : false,
    configurable : true,
    value : function (args) { 
        for(var i = 0; i < args.length; i++) {
            this.push(args[i]);
        }
        return this.length; 
    }
});

var p5tie_array = function(v, List__) {
    var pkg_name = p5str(List__.shift());

    var res = p5call(pkg_name, 'TIEARRAY', List__, null);
    
    // TODO
    
    //  A class implementing an ordinary array should have the following methods:
    //      TIEARRAY pkg_name, LIST
    //      FETCH this, key
    //      STORE this, key, value
    //      FETCHSIZE this
    //      STORESIZE this, count
    //      CLEAR this
    //      PUSH this, LIST
    //      POP this
    //      SHIFT this
    //      UNSHIFT this, LIST
    //      SPLICE this, offset, length, LIST
    //      EXTEND this, count
    //      DESTROY this
    //      UNTIE this
    
    Object.defineProperty( v, "p5aget", {
        enumerable : false,
        configurable : true,
        value : function (i) {
            return p5call(res, 'FETCH', [i]);
        }
    });
    Object.defineProperty( v, "p5aset", {
        enumerable : false,
        configurable : true,
        value : function (i, value) {
            p5call(res, 'STORE', [i, value]);
            return value;
        }
    });
    Object.defineProperty( v, "p5incr", {
        enumerable : false,
        configurable : true,
        value : function (i) {
            var value = p5incr_(p5call(res, 'FETCH', [i]));
            p5call(res, 'STORE', [i, value]);
            return value;
        }
    });
    Object.defineProperty( v, "p5postincr", {
        enumerable : false,
        configurable : true,
        value : function (i) {
            var value = p5call(res, 'FETCH', [i]);
            p5call(res, 'STORE', [i, p5incr_(value)]);
            return value;
        }
    });
    Object.defineProperty( v, "p5decr", {
        enumerable : false,
        configurable : true,
        value : function (i) {
            var value = p5decr_(p5call(res, 'FETCH', [i]));
            p5call(res, 'STORE', [i, value]);
            return value;
        }
    });
    Object.defineProperty( v, "p5postdecr", {
        enumerable : false,
        configurable : true,
        value : function (i) {
            var value = p5call(res, 'FETCH', [i]);
            p5call(res, 'STORE', [i, p5decr_(value)]);
            return value;
        }
    });
    
    Object.defineProperty( v, "p5aget_array", {
        enumerable : false,
        configurable : true,
        value : function (i) {
            var value = p5call(res, 'FETCH', [i]);
            if (value == null) {
                value = new p5ArrayRef([]);
                p5call(res, 'STORE', [i, value]);
            }
            return value;
        }
    });
    Object.defineProperty( v, "p5aget_hash", {
        enumerable : false,
        configurable : true,
        value : function (i) {
            var value = p5call(res, 'FETCH', [i]);
            if (value == null) {
                value = new p5HashRef({});
                p5call(res, 'STORE', [i, value]);
            }
            return value;
        }
    });
    Object.defineProperty( v, "p5untie", {
        enumerable : false,
        configurable : true,
        value : function (i) { return p5call(res, 'UNTIE', []) }
    });
    Object.defineProperty( v, "shift", {
        enumerable : false,
        configurable : true,
        value : function () { return p5call(res, 'SHIFT', []) }
    });
    Object.defineProperty( v, "pop", {
        enumerable : false,
        configurable : true,
        value : function () { return p5call(res, 'POP', []) }
    });
    Object.defineProperty( v, "p5unshift", {
        enumerable : false,
        configurable : true,
        value : function (args) { 
            for(var i = args.length-1; i >= 0; i--) {
                p5call(res, 'UNSHIFT', [args[i]]);
            }
            return p5call(res, 'FETCHSIZE', []); 
        }
    });
    Object.defineProperty( v, "p5push", {
        enumerable : false,
        configurable : true,
        value : function (args) { 
            for(var i = 0; i < args.length; i++) {
                p5call(res, 'PUSH', [args[i]]);
            }
            return p5call(res, 'FETCHSIZE', []); 
        }
    });

    return res;
};

var p5untie_array = function(v) {
    if (v.hasOwnProperty('p5untie')) {
        var res = v.p5untie();  // call UNTIE
        delete v.p5aget;
        delete v.p5aset;
        delete v.p5incr;
        delete v.p5postincr;
        delete v.p5decr;
        delete v.p5postdecr;
        delete v.p5aget_array;
        delete v.p5aget_hash;
        delete v.p5untie;
        delete v.shift;
        delete v.pop;
        delete v.p5unshift;
        delete v.p5push;
        return res;
    }
    else {
        return null;
    }
};


function p5ArrayOfAlias(o) {

    // this is the structure that represents @_
    // _array = [ ref, index,
    //            ref, index,
    //            ...
    //          ]

    // TODO - autovivify array cells

    this._array_ = o;

    this.p5aget = function (i) {
        if (i < 0) { i =  this.length + i };
        return this._array_[i+i][this._array_[i+i+1]]; 
    }
    this.p5aset = function (i, v) {
        if (i < 0) { i =  this.length + i };
        this._array_[i+i][this._array_[i+i+1]] = v;
        return this._array_[i+i][this._array_[i+i+1]]
    }
    this.p5incr = function (i) {
        if (i < 0) { i =  this.length + i };
        this._array_[i+i][this._array_[i+i+1]] = p5incr_(this._array_[i+i][this._array_[i+i+1]]);
        return this._array_[i+i][this._array_[i+i+1]];
    }
    this.p5postincr = function (i) {
        if (i < 0) { i =  this.length + i };
        var v = this._array_[i+i][this._array_[i+i+1]];
        this._array_[i+i][this._array_[i+i+1]] = p5incr_(this._array_[i+i][this._array_[i+i+1]]);
        return v;
    }
    this.p5decr = function (i) {
        if (i < 0) { i =  this.length + i };
        this._array_[i+i][this._array_[i+i+1]] = p5decr_(this._array_[i+i][this._array_[i+i+1]]);
        return this._array_[i+i][this._array_[i+i+1]];
    }
    this.p5postdecr = function (i) {
        if (i < 0) { i =  this.length + i };
        var v = this._array_[i+i][this._array_[i+i+1]];
        this._array_[i+i][this._array_[i+i+1]] = p5decr_(this._array_[i+i][this._array_[i+i+1]]);
        return v;
    }
    this.p5aget_array = function (i) {
        if (i < 0) { i =  this.length + i };
        if (this._array_[i+i][this._array_[i+i+1]] == null) {
            this._array_[i+i][this._array_[i+i+1]] = new p5ArrayRef([])
        }
        return this._array_[i+i][this._array_[i+i+1]]
    }
    this.p5aget_hash = function (i) {
        if (i < 0) { i =  this.length + i };
        if (this._array_[i+i][this._array_[i+i+1]] == null) {
            this._array_[i+i][this._array_[i+i+1]] = new p5HashRef({})
        }
        return this._array_[i+i][this._array_[i+i+1]]
    }
    this.p5unshift = function (args) { 
        for(var i = args.length-1; i >= 0; i--) {
            this.unshift(0);
            this.unshift([args[i]]);
        }
        return this._array_.length / 2; 
    }
    this.p5push = function (args) { 
        for(var i = 0; i < args.length; i++) {
            this.push([args[i]]);
            this.push(0);
        }
        return this._array_.length / 2; 
    }
    this.shift = function () { 
        var v0 = this._array_.shift();
        return v0[this._array_.shift()];
    }
    this.pop = function () { 
        var v1 = this._array_.pop();
        var v0 = this._array_.pop();
        return v0[v1];
    }
}


EOT

} # end of emit_javascript2()

1;


