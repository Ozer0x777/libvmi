# exact body of the "calculate complexity" steps; $1 = where to write complexity.score
autoreconf -vif
scan-build-$VERSION --status-bugs -disable-checker deadcode.DeadStores ./configure CFLAGS=-DVMI_DEBUG=__VMI_DEBUG_ALL --enable-debug --disable-config-file
intercept-build-$VERSION make
run-clang-tidy-$VERSION -quiet -config="{Checks: 'readability-function-cognitive-complexity', CheckOptions: [{key: readability-function-cognitive-complexity.Threshold, value: 0}, {key: readability-function-cognitive-complexity.DescribeBasicIncrements, value: False}]}" \
    2>/dev/null | grep warning | grep "cognitive complexity" > cognitive-complexity.log || :
complexity=0
while read -r log; do
    file=$(echo $log | awk -F":" '{ print $1 }')
    line=$(echo $log | awk -F":" '{ print $2 }')
    function=$(echo $log | awk -F"function" '{ print $2 }' | awk '{ print $1 }' | sed "s/'//g")
    score=$(echo $log | awk -F"cognitive complexity of" '{ print $2 }' | awk '{ print $1 }')
    [[ $score -lt 25 ]] && continue
    echo "Complex function found: $file:$line $function(), complexity score: $score" | tee -a complex-functions.log
    complexity=$(( complexity + score ))
done < cognitive-complexity.log
echo "Final complexity sum of complex functions: $complexity"
