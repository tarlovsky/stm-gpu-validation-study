#include "benchmark.h"
#include "parameters.h"

using namespace sb7;

int main(int argc, char **argv) {
	// initialize parameters
	if(parameters.init(argc, argv, cout)) {
		//parameters.print(cout);/*tarlovskyy*/

		// create benchmark object and run it
		Benchmark benchmark;
		benchmark.init();
		benchmark.start();
		//benchmark.report(cout); /*tarlovskyy*/
		sb7::global_clean_tm();
	}
}
