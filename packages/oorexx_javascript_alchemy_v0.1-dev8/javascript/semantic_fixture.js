'use strict';
class Animal { constructor(name){ this.name=name; } self(){ return this; } }
class Dog extends Animal { greet(prefix='hello'){ return `${prefix} ${this.name}`; } }
function makeFixture(){
 const dog=new Dog('Ada');
 return {
  dog,
  collection:[dog,0,'',null,undefined],
  callback(obj,fn){ return fn(obj); },
  promiseValue(){ return Promise.resolve(dog); },
  thrower(){ throw new TypeError('fixture-boom'); }
 };
}
module.exports={Animal,Dog,makeFixture};
