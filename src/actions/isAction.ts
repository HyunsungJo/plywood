module Plywood {
  export class IsAction extends Action {
    static fromJS(parameters: ActionJS): IsAction {
      return new IsAction(Action.jsToValue(parameters));
    }

    constructor(parameters: ActionValue) {
      super(parameters, dummyObject);
      this._ensureAction("is");
    }

    public getOutputType(inputType: string): string {
      var expressionType = this.expression.type;
      if (expressionType !== 'NULL') this._checkInputType(inputType, expressionType);
      return 'BOOLEAN';
    }

    protected _getFnHelper(inputFn: ComputeFn, expressionFn: ComputeFn): ComputeFn {
      return (d: Datum, c: Datum) => {
        return inputFn(d, c) === expressionFn(d, c);
      }
    }

    protected _getJSHelper(inputJS: string, expressionJS: string): string {
      return `(${inputJS}===${expressionJS})`;
    }

    protected _getSQLHelper(dialect: SQLDialect, inputSQL: string, expressionSQL: string): string {
      return `(${inputSQL}=${expressionSQL})`;
    }

    protected _performOnLiteral(literalExpression: LiteralExpression): Expression {
      var expression = this.expression;
      if (expression instanceof RefExpression) {
        return expression.is(literalExpression);
      }
      return null;
    }

    protected _performOnRef(refExpression: RefExpression): Expression {
      if (this.expression.equals(refExpression)) {
        return Expression.TRUE;
      }
      return null;
    }

    protected _performOnChain(chainExpression: ChainExpression): Expression {
      if (this.expression.equals(chainExpression)) {
        return Expression.TRUE;
      }

      var actions = chainExpression.actions;
      var lastAction = actions[actions.length - 1];
      var literalValue = this.getLiteralValue();
      if (lastAction instanceof TimeBucketAction && literalValue instanceof TimeRange) {
        var duration = lastAction.duration;
        var timezone = lastAction.timezone;
        var start = literalValue.start;
        var end = literalValue.end;

        if (duration.isSimple()) {
          if (duration.floor(start, timezone).valueOf() === start.valueOf() &&
            duration.move(start, timezone, 1).valueOf() === end.valueOf()) {

            actions = actions.slice(0, -1);
            actions.push(new InAction({
              expression: this.expression
            }));

            var chainExpressionValue = chainExpression.valueOf();
            chainExpressionValue.actions = actions;
            return new ChainExpression(chainExpressionValue);
          } else {
            return Expression.FALSE;
          }
        }
      }
      return null;
    }
  }

  Action.register(IsAction);
}
