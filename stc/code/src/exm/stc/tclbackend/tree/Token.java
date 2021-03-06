/*
 * Copyright 2013 University of Chicago and Argonne National Laboratory
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License
 */

package exm.stc.tclbackend.tree;

/**
 * Represents a simple Tcl token (e.g., word)
 * @author wozniak
 * */
public class Token extends Expression
{
  String token;

  public Token(String token)
  {
    this.token = token;
  }

  public Token(int target)
  {
    this.token = String.valueOf(target);
  }

  @Override
  public void appendTo(StringBuilder sb, ExprContext mode)
  {
    sb.append(token);
  }

  public String value() {
    return this.token;
  }

  @Override
  public boolean supportsStringList() {
    return true;
  }
}
