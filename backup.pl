addExp(Out, InMap) --> mulExp(X, InMap), addExpTail(X, Out, InMap).
addExpTail(In, Out, InMap) --> {member(AddMinus, ['+', '-'])}, [AddMinus], mulExp(Y, InMap), {X =.. [AddMinus, In, Y]}, addExpTail(X, Out, InMap).
addExpTail(In, In, _InMap) --> [].

mulExp(Out, InMap) --> item(X, InMap), mulExpTail(X, Out, InMap).
mulExpTail(In, Out, InMap) --> {member(MulDiv, ['*', '/'])}, [MulDiv], item(Y, InMap), {X =.. [MulDiv, In, Y]}, mulExpTail(X, Out, InMap).
mulExpTail(In, In, _InMap) --> [].