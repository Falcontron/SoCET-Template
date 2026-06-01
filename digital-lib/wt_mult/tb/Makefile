# Possible targets:
# u4_build, u4_test,
# u8_build, u8_test,
# u16_build, u16_test,
# u24_build, u24_test,
# u32_build, u32_test,
# u53_build, u53_test,
# u64_build, u64_test
# i4_build, i4_test,
# i8_build, i8_test,
# i16_build, i16_test,
# i24_build, i24_test,
# i32_build, i32_test,
# i53_build, i53_test,
# i64_build, i64_test

targets = u4 u8 u16 u24 u32 u53 u64 i4 i8 i16 i24 i32 i53 i64

define build_test_template

$1_build: mul_test.cc
	fusesoc --cores-root ../ run --setup --build --build-root build --target tb_$1 socet:digital-lib:wt_mult_tb:0.0.1 --make_options='-j'

$1_test: $1_build
	./build/socet_digital-lib_wt_mult_tb_0.0.1/tb_$1-verilator/Vwt_mult --seed $$(shell date +%s)

endef


$(foreach element, $(targets), $(eval $(call build_test_template,$(element))))
clean:
	rm -rf build
	rm -rf *.fst
