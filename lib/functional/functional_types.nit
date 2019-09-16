# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This module provides functional type to represents various function forms.
# Function types can hold up to 20 arguments. The type `Fun` is for function
# (input and output) and `Proc` is for procedure (input but no output).
# This file is automatically generated, do not edit it manually.
module functional_types

interface Routine
end
interface Fun
        super Routine
end
interface Proc
        super Routine
end
interface Fun0[RESULT]
	super Fun
	fun call: RESULT is abstract
end
interface Proc0
	super Proc
	fun call is abstract
end
interface Fun1[A0,RESULT]
	super Fun
	fun call(a0: A0): RESULT is abstract
end
interface Proc1[A0]
	super Proc
	fun call(a0: A0) is abstract
end
interface Fun2[A0,A1,RESULT]
	super Fun
	fun call(a0: A0,a1: A1): RESULT is abstract
end
interface Proc2[A0,A1]
	super Proc
	fun call(a0: A0,a1: A1) is abstract
end
interface Fun3[A0,A1,A2,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2): RESULT is abstract
end
interface Proc3[A0,A1,A2]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2) is abstract
end
interface Fun4[A0,A1,A2,A3,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3): RESULT is abstract
end
interface Proc4[A0,A1,A2,A3]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3) is abstract
end
interface Fun5[A0,A1,A2,A3,A4,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4): RESULT is abstract
end
interface Proc5[A0,A1,A2,A3,A4]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4) is abstract
end
interface Fun6[A0,A1,A2,A3,A4,A5,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5): RESULT is abstract
end
interface Proc6[A0,A1,A2,A3,A4,A5]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5) is abstract
end
interface Fun7[A0,A1,A2,A3,A4,A5,A6,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6): RESULT is abstract
end
interface Proc7[A0,A1,A2,A3,A4,A5,A6]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6) is abstract
end
interface Fun8[A0,A1,A2,A3,A4,A5,A6,A7,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7): RESULT is abstract
end
interface Proc8[A0,A1,A2,A3,A4,A5,A6,A7]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7) is abstract
end
interface Fun9[A0,A1,A2,A3,A4,A5,A6,A7,A8,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8): RESULT is abstract
end
interface Proc9[A0,A1,A2,A3,A4,A5,A6,A7,A8]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8) is abstract
end
interface Fun10[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9): RESULT is abstract
end
interface Proc10[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9) is abstract
end
interface Fun11[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10): RESULT is abstract
end
interface Proc11[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10) is abstract
end
interface Fun12[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11): RESULT is abstract
end
interface Proc12[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11) is abstract
end
interface Fun13[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12): RESULT is abstract
end
interface Proc13[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12) is abstract
end
interface Fun14[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13): RESULT is abstract
end
interface Proc14[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13) is abstract
end
interface Fun15[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14): RESULT is abstract
end
interface Proc15[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14) is abstract
end
interface Fun16[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14,a15: A15): RESULT is abstract
end
interface Proc16[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14,a15: A15) is abstract
end
interface Fun17[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14,a15: A15,a16: A16): RESULT is abstract
end
interface Proc17[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14,a15: A15,a16: A16) is abstract
end
interface Fun18[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14,a15: A15,a16: A16,a17: A17): RESULT is abstract
end
interface Proc18[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14,a15: A15,a16: A16,a17: A17) is abstract
end
interface Fun19[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17,A18,RESULT]
	super Fun
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14,a15: A15,a16: A16,a17: A17,a18: A18): RESULT is abstract
end
interface Proc19[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17,A18]
	super Proc
	fun call(a0: A0,a1: A1,a2: A2,a3: A3,a4: A4,a5: A5,a6: A6,a7: A7,a8: A8,a9: A9,a10: A10,a11: A11,a12: A12,a13: A13,a14: A14,a15: A15,a16: A16,a17: A17,a18: A18) is abstract
end
universal FunRef0[RESULT]
	super Fun0[RESULT]
	redef fun call: RESULT is intern
end
universal ProcRef0
	super Proc0
	redef fun call is intern
end
universal FunRef1[A0,RESULT]
	super Fun1[A0,RESULT]
	redef fun call(a0): RESULT is intern
end
universal ProcRef1[A0]
	super Proc1[A0]
	redef fun call(a0) is intern
end
universal FunRef2[A0,A1,RESULT]
	super Fun2[A0,A1,RESULT]
	redef fun call(a0,a1): RESULT is intern
end
universal ProcRef2[A0,A1]
	super Proc2[A0,A1]
	redef fun call(a0,a1) is intern
end
universal FunRef3[A0,A1,A2,RESULT]
	super Fun3[A0,A1,A2,RESULT]
	redef fun call(a0,a1,a2): RESULT is intern
end
universal ProcRef3[A0,A1,A2]
	super Proc3[A0,A1,A2]
	redef fun call(a0,a1,a2) is intern
end
universal FunRef4[A0,A1,A2,A3,RESULT]
	super Fun4[A0,A1,A2,A3,RESULT]
	redef fun call(a0,a1,a2,a3): RESULT is intern
end
universal ProcRef4[A0,A1,A2,A3]
	super Proc4[A0,A1,A2,A3]
	redef fun call(a0,a1,a2,a3) is intern
end
universal FunRef5[A0,A1,A2,A3,A4,RESULT]
	super Fun5[A0,A1,A2,A3,A4,RESULT]
	redef fun call(a0,a1,a2,a3,a4): RESULT is intern
end
universal ProcRef5[A0,A1,A2,A3,A4]
	super Proc5[A0,A1,A2,A3,A4]
	redef fun call(a0,a1,a2,a3,a4) is intern
end
universal FunRef6[A0,A1,A2,A3,A4,A5,RESULT]
	super Fun6[A0,A1,A2,A3,A4,A5,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5): RESULT is intern
end
universal ProcRef6[A0,A1,A2,A3,A4,A5]
	super Proc6[A0,A1,A2,A3,A4,A5]
	redef fun call(a0,a1,a2,a3,a4,a5) is intern
end
universal FunRef7[A0,A1,A2,A3,A4,A5,A6,RESULT]
	super Fun7[A0,A1,A2,A3,A4,A5,A6,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6): RESULT is intern
end
universal ProcRef7[A0,A1,A2,A3,A4,A5,A6]
	super Proc7[A0,A1,A2,A3,A4,A5,A6]
	redef fun call(a0,a1,a2,a3,a4,a5,a6) is intern
end
universal FunRef8[A0,A1,A2,A3,A4,A5,A6,A7,RESULT]
	super Fun8[A0,A1,A2,A3,A4,A5,A6,A7,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7): RESULT is intern
end
universal ProcRef8[A0,A1,A2,A3,A4,A5,A6,A7]
	super Proc8[A0,A1,A2,A3,A4,A5,A6,A7]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7) is intern
end
universal FunRef9[A0,A1,A2,A3,A4,A5,A6,A7,A8,RESULT]
	super Fun9[A0,A1,A2,A3,A4,A5,A6,A7,A8,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8): RESULT is intern
end
universal ProcRef9[A0,A1,A2,A3,A4,A5,A6,A7,A8]
	super Proc9[A0,A1,A2,A3,A4,A5,A6,A7,A8]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8) is intern
end
universal FunRef10[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,RESULT]
	super Fun10[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9): RESULT is intern
end
universal ProcRef10[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9]
	super Proc10[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9) is intern
end
universal FunRef11[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,RESULT]
	super Fun11[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10): RESULT is intern
end
universal ProcRef11[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10]
	super Proc11[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10) is intern
end
universal FunRef12[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,RESULT]
	super Fun12[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11): RESULT is intern
end
universal ProcRef12[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11]
	super Proc12[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11) is intern
end
universal FunRef13[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,RESULT]
	super Fun13[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12): RESULT is intern
end
universal ProcRef13[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12]
	super Proc13[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12) is intern
end
universal FunRef14[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,RESULT]
	super Fun14[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13): RESULT is intern
end
universal ProcRef14[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13]
	super Proc14[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13) is intern
end
universal FunRef15[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,RESULT]
	super Fun15[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14): RESULT is intern
end
universal ProcRef15[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14]
	super Proc15[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14) is intern
end
universal FunRef16[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,RESULT]
	super Fun16[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15): RESULT is intern
end
universal ProcRef16[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15]
	super Proc16[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15) is intern
end
universal FunRef17[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,RESULT]
	super Fun17[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16): RESULT is intern
end
universal ProcRef17[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16]
	super Proc17[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16) is intern
end
universal FunRef18[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17,RESULT]
	super Fun18[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17): RESULT is intern
end
universal ProcRef18[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17]
	super Proc18[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17) is intern
end
universal FunRef19[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17,A18,RESULT]
	super Fun19[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17,A18,RESULT]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17,a18): RESULT is intern
end
universal ProcRef19[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17,A18]
	super Proc19[A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17,A18]
	redef fun call(a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15,a16,a17,a18) is intern
end
universal RoutineRef
end
