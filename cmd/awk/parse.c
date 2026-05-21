#include "awk.def"
#include "awk.h"
#include "stdio.h"
int error();
node *ALLOC(int n)
{	node *x;
	x = (node *)malloc(sizeof(node)+n*sizeof(node *));
	if (x == NULL)
		error(FATAL, "out of space in ALLOC");
	return(x);
}
node *exptostat(node *a)
{
	a->ntype = NSTAT;
	return(a);
}
node	*nullstat;
node *node0(int a)
{	node *x;
	x=ALLOC(0);
	x->nnext = NULL;
	x->nobj=a;
	return(x);
}
node *node1(int a, node *b)
{	node *x;
	x=ALLOC(1);
	x->nnext = NULL;
	x->nobj=a;
	x->narg[0]=b;
	return(x);
}
node *node2(int a, node *b, node *c)
{	node *x;
	x = ALLOC(2);
	x->nnext = NULL;
	x->nobj = a;
	x->narg[0] = b;
	x->narg[1] = c;
	return(x);
}
node *node3(int a, node *b, node *c, node *d)
{	node *x;
	x = ALLOC(3);
	x->nnext = NULL;
	x->nobj = a;
	x->narg[0] = b;
	x->narg[1] = c;
	x->narg[2] = d;
	return(x);
}
node *node4(int a, node *b, node *c, node *d, node *e)
{	node *x;
	x = ALLOC(4);
	x->nnext = NULL;
	x->nobj = a;
	x->narg[0] = b;
	x->narg[1] = c;
	x->narg[2] = d;
	x->narg[3] = e;
	return(x);
}
node *stat3(int a, node *b, node *c, node *d)
{	node *x;
	x = node3(a,b,c,d);
	x->ntype = NSTAT;
	return(x);
}
node *op2(int a, node *b, node *c)
{	node *x;
	x = node2(a,b,c);
	x->ntype = NEXPR;
	return(x);
}
node *op1(int a, node *b)
{	node *x;
	x = node1(a,b);
	x->ntype = NEXPR;
	return(x);
}
node *stat1(int a, node *b)
{	node *x;
	x = node1(a,b);
	x->ntype = NSTAT;
	return(x);
}
node *op3(int a, node *b, node *c, node *d)
{	node *x;
	x = node3(a,b,c,d);
	x->ntype = NEXPR;
	return(x);
}
node *stat2(int a, node *b, node *c)
{	node *x;
	x = node2(a,b,c);
	x->ntype = NSTAT;
	return(x);
}
node *stat4(int a, node *b, node *c, node *d, node *e)
{	node *x;
	x = node4(a,b,c,d,e);
	x->ntype = NSTAT;
	return(x);
}
node *valtonode(cell *a, int b)
{	node *x;
	x = node0((int)a);
	x->ntype = NVALUE;
	x->subtype = b;
	return(x);
}
node *genjump(int a)
{	node *x;
	x = node0(a);
	x->ntype = NSTAT;
	return(x);
}
node *pa2stat(node *a, node *b, node *c)
{	node *x;
	x = node3(paircnt++, a, b, c);
	x->ntype = NPA2;
	return(x);
}
node *linkum(node *a, node *b)
{	node *c;
	if(a == NULL) return(b);
	else if(b == NULL) return(a);
	for(c=a; c->nnext != NULL; c=c->nnext);
	c->nnext = b;
	return(a);
}
node *genprint(void)
{	node *x;
	x = stat2(PRINT,valtonode(lookup("$record", symtab), CFLD), nullstat);
	return(x);
}
