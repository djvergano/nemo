class FormSelect extends React.Component {
  render() {
    let options = [];
    if (this.props.prompt || this.props.includeBlank !== false) {
      options.push(<option
        key="blank"
        value="">
        {this.props.prompt || ""}
      </option>);
    }
    let fullOptions = options.concat(this.props.options.map((o) => (<option
      key={o.id}
      value={o.id}>
      {o.name}
    </option>)));
    let props = {
      className: "form-control",
      name: this.props.name,
      id: this.props.id,
      key: this.props.id,
      defaultValue: this.props.value
    };
    if (this.props.changeFunc) {
      props["onChange"] = (e) => this.props.changeFunc(e.target.value);
    }
    return (
      <select {...props} >
        {fullOptions}
      </select>
    );
  }
}
