{ }:
{
  # local reimplementation of 'assertMsg'
  bigErrorMsg = pred: msg:
    if pred
    then true
    else builtins.trace ''

      #########################################################
      ${ msg }
      #########################################################'' false;

}
