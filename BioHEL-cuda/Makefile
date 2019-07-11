SUFFIX=
EXEC=biohel biohelcuda


OBJS=random.o classifier_gabil.o classifierFitness.o instanceSet.o \
	lex.yy.o instance.o timeManagement.o JString.o populationWrapper.o \
	timersManagement.o ga.o factory.o attributesInfo.o timerHierar.o \
	timerMDL.o timerSymbolicKR.o timerRealKR.o agentPerformance.o utils.o \
	timerGlobals.o timerMutation.o timerEvolutionStats.o windowingILAS.o \
	timerCrossover.o classifier_hyperrect.o mtwist.o \
	agentPerformanceTraining.o classifier_hyperrect_sse.o \
	classifier_rotated_hyperrect.o classifier_hyperrect_list.o windowingGWS.o \
	classifier_hyperrect_list_real.o classifier_hyperrect_list_discrete.o


CUDA_OBJS=functions.o kernels.cu.o random.o classifier_gabil.o classifierFitness.o instanceSet.o \
	lex.yy.o instance.o timeManagement.o JString.o populationWrapper.o \
	timersManagement.o ga.o factory.o attributesInfo.o timerHierar.o \
	timerMDL.o timerSymbolicKR.o timerRealKR.o agentPerformance.o utils.o \
	timerGlobals.o timerMutation.o timerEvolutionStats.o windowingILAS.o \
	timerCrossover.o classifier_hyperrect.o mtwist.o \
	agentPerformanceTraining.o classifier_hyperrect_sse.o \
	classifier_rotated_hyperrect.o classifier_hyperrect_list.o windowingGWS.o \
	classifier_hyperrect_list_real.o classifier_hyperrect_list_discrete.o


CFLAGS=-O3 -march=native -D__CUDA_COMPILED__=1
#To create the non-cuda version of BioHEL use the line below
#CFLAGS=-O3 -march=native -D__CUDA_COMPILED__=0


LDFLAGS=-fPIC  
END_LDFLAGS=-L/usr/local/cuda/lib64/ -lcuda -lcudart 
CC=g++
LEX=flex
NVCC=/usr/local/cuda/bin/nvcc
CUFLAGS=-O3 --ptxas-options=-v --compiler-options -DUNIX 

default: biohel

cuda: cudabuild biohelcuda

biohel: ${OBJS} main.o
	${CC} ${LDFLAGS} ${OBJS} main.o -o biohel 

biohelcuda: ${CUDA_OBJS} main.o
	${CC} ${LDFLAGS} ${CUDA_OBJS} main.o -o biohelcuda ${END_LDFLAGS}

cudabuild:
	${NVCC} ${CUFLAGS} -o kernels.cu.o -c kernels.cu

dep:
	${CC} -MM ${CFLAGS} *.cpp > .depend

.cpp.o:
	${CC} ${CFLAGS} -c $<

.c.o:
	${CC} ${CFLAGS} -c $<


clean:
	rm -f *.o core ${EXEC}

lex.yy.o: lex.yy.cpp configManagement.h dictionary.h configCodes.h \
  JVector.h M95_types.h \
  attributesInfo.h JString.h instance.h random.h mt19937ar-cok.h lex_conf.l
	${LEX} -i -olex.yy.cpp lex_conf.l
	${CC} ${CFLAGS} -c lex.yy.cpp

include .depend
