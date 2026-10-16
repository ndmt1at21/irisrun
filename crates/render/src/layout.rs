//! Auto Layout's linear constraints, solved by the Cassowary simplex of the
//! kasuari crate: OpenUIKit's NSLayoutConstraint engine adds and removes
//! constraints over numbered variables and reads the variables' values, which
//! the solver keeps optimal after every change.

use std::collections::BTreeMap;

use kasuari::{
    AddConstraintError, Constraint, Expression, RelationalOperator, Solver, Strength, Term,
    Variable,
};

/// The strength of a constraint that must hold; weaker ones are wishes, met as
/// far as the required ones and stronger wishes let them.
pub const REQUIRED: f64 = Strength::REQUIRED.value();

/// How a constraint's expression compares to zero, by the raw values of
/// NSLayoutConstraint.Relation.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Relation {
    LessOrEqual = -1,
    Equal = 0,
    GreaterOrEqual = 1,
}

#[derive(Default)]
pub struct LayoutSolver {
    solver: Solver,
    variables: Vec<Variable>,
    /// By id, which is the order they came in.
    constraints: BTreeMap<u64, Constraint>,
    last_id: u64,
}

impl LayoutSolver {
    pub fn new() -> Self {
        Self::default()
    }

    /// A new variable, numbered from 0 up. It is 0 until a constraint moves it.
    pub fn add_variable(&mut self) -> u32 {
        self.variables.push(Variable::new());
        (self.variables.len() - 1) as u32
    }

    /// Adds `sum(coefficient × variable) + constant <relation> 0` at
    /// `strength`. None, and no change, if the variables aren't this solver's,
    /// or if it is required and contradicts the required constraints in the
    /// solver.
    pub fn add(
        &mut self,
        terms: &[(u32, f64)],
        constant: f64,
        relation: Relation,
        strength: f64,
    ) -> Option<u64> {
        let terms = terms
            .iter()
            .map(|&(variable, coefficient)| {
                Some(Term::new(
                    *self.variables.get(variable as usize)?,
                    coefficient,
                ))
            })
            .collect::<Option<Vec<_>>>()?;
        let op = match relation {
            Relation::LessOrEqual => RelationalOperator::LessOrEqual,
            Relation::Equal => RelationalOperator::Equal,
            Relation::GreaterOrEqual => RelationalOperator::GreaterOrEqual,
        };
        let constraint = Constraint::new(
            Expression::new(terms, constant),
            op,
            Strength::new(strength),
        );
        match self.solver.add_constraint(constraint.clone()) {
            Ok(()) => {
                self.last_id += 1;
                self.constraints.insert(self.last_id, constraint);
                Some(self.last_id)
            }
            Err(AddConstraintError::UnsatisfiableConstraint) => {
                // A failed add can leave the tableau pivoted halfway, its
                // objective no longer optimal: solve the constraints anew.
                self.solver = Solver::new();
                for constraint in self.constraints.values() {
                    self.solver
                        .add_constraint(constraint.clone())
                        .expect("they were satisfiable");
                }
                None
            }
            // Each constraint is new, and the simplex keeps its invariants.
            Err(error) => unreachable!("{error}"),
        }
    }

    /// False if the constraint isn't in the solver.
    pub fn remove(&mut self, id: u64) -> bool {
        self.constraints
            .remove(&id)
            .is_some_and(|constraint| self.solver.remove_constraint(&constraint).is_ok())
    }

    /// 0 for a variable no constraint moves, or one that isn't this solver's.
    pub fn value(&self, variable: u32) -> f64 {
        self.variables
            .get(variable as usize)
            .map_or(0.0, |&variable| self.solver.get_value(variable))
    }
}
